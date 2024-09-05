defmodule Since.Chats do
  @moduledoc "Chats"

  import Ecto.{Query, Changeset}
  alias Ecto.Multi

  require Logger
  require Since.Geo

  alias Since.{Repo, Bot}
  alias Since.Chats.{Chat, Message}
  alias Since.Feeds.{FeedProfile, SeenProfile}
  alias Since.PushNotifications.DispatchJob

  @type uuid :: Ecto.UUID.t()

  # - PubSub

  @pubsub Since.PubSub
  @topic "__c"

  defp pubsub_user_topic(user_id) when is_binary(user_id) do
    @topic <> ":u:" <> String.downcase(user_id)
  end

  def subscribe_for_user(user_id) do
    Phoenix.PubSub.subscribe(@pubsub, pubsub_user_topic(user_id))
  end

  defp broadcast_for_user(user_id, message) do
    Phoenix.PubSub.broadcast(@pubsub, pubsub_user_topic(user_id), message)
  end

  defp broadcast_from_for_user(user_id, message) do
    Phoenix.PubSub.broadcast_from(@pubsub, self(), pubsub_user_topic(user_id), message)
  end

  def list_chats(user_id, h3) do
    Chat
    |> where([c], c.user_id_1 == ^user_id or c.user_id_2 == ^user_id)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
    |> preload_chat_profiles(user_id, h3)
    |> preload_messages()
  end

  # TODO cleanup
  defp preload_chat_profiles(chats, user_id, h3) do
    mate_chats =
      Map.new(chats, fn chat ->
        [mate_id] = [chat.user_id_1, chat.user_id_2] -- [user_id]
        {mate_id, chat}
      end)

    mates = Map.keys(mate_chats)

    profiles =
      FeedProfile
      |> where([p], p.user_id in ^mates)
      |> select([p], %{p | distance: Since.Geo.h3_great_circle_distance_km(^h3, p.h3)})
      |> Repo.all()
      |> Map.new(fn profile -> {profile.user_id, profile} end)

    Enum.map(chats, fn chat ->
      [mate_id] = [chat.user_id_1, chat.user_id_2] -- [user_id]
      %Chat{chat | profile: Map.fetch!(profiles, mate_id)}
    end)
  end

  defp preload_messages(chats) do
    chat_ids = chats |> Enum.map(fn chat -> chat.id end)

    messages =
      Message
      |> where([m], m.chat_id in ^chat_ids)
      |> order_by(:id)
      |> Repo.all()

    Enum.map(chats, fn chat ->
      %Chat{chat | messages: Enum.filter(messages, fn m -> m.chat_id == chat.id end)}
    end)
  end

  @spec delete_chat(uuid, uuid) :: boolean
  def delete_chat(by_user_id, with_user_id) do
    Logger.warning("#{by_user_id} deletes chat with user #{with_user_id}")

    [user_id_1, user_id_2] = Enum.sort([by_user_id, with_user_id])

    Multi.new()
    |> Multi.run(:delete_chat, fn _repo, _changes ->
      Chat
      |> where([c], c.user_id_1 == ^user_id_1 and c.user_id_2 == ^user_id_2)
      |> Repo.delete_all()
      |> case do
        {1, _} -> {:ok, [user_id_1, user_id_2]}
        {0, _} -> {:error, :chat_not_found}
      end
    end)
    |> mark_chatters_seen_m()
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        notify_delete_chat(by_user_id, with_user_id)
        _deleted_chat? = true

      {:error, :delete_chat, :chat_not_found, _changes} ->
        _deleted_chat? = false
    end
  end

  @spec delete_chat_multi(Multi.t(), uuid, uuid) :: Multi.t()
  def delete_chat_multi(multi, by_user_id, mate) do
    [user_id_1, user_id_2] = Enum.sort([by_user_id, mate])

    Multi.run(multi, :delete_chat, fn _repo, _changes ->
      chat_id =
        Chat
        |> where(user_id_1: ^user_id_1)
        |> where(user_id_2: ^user_id_2)
        |> select([c], c.id)
        |> Repo.one()

      if chat_id do
        {1, _} =
          Chat
          |> where(id: ^chat_id)
          |> Repo.delete_all()

        {:ok, fn -> notify_delete_chat(by_user_id, mate) end}
      else
        {:ok, nil}
      end
    end)
  end

  # called from accounts on report
  def notify_delete_chat_changes(%{delete_chat: chat}) do
    case chat do
      notify_delete_chat when is_function(notify_delete_chat, 0) -> notify_delete_chat.()
      nil -> :ok
    end
  end

  defp mark_chatters_seen_m(multi) do
    Multi.run(multi, :mark_seen, fn _repo, %{delete_chat: user_ids} ->
      [uid1, uid2] =
        case user_ids do
          [_uid1, _uid2] = ids -> ids
          %{users: [_uid1, _uid2] = ids} -> ids
        end

      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      {count, _} =
        Repo.insert_all(
          SeenProfile,
          [
            %{by_user_id: uid1, user_id: uid2, inserted_at: now},
            %{by_user_id: uid2, user_id: uid1, inserted_at: now}
          ],
          on_conflict: {:replace, [:inserted_at]},
          conflict_target: [:by_user_id, :user_id]
        )

      {:ok, count}
    end)
  end

  defp notify_delete_chat(by_user_id, with_user_id) do
    broadcast_for_user(with_user_id, {__MODULE__, :deleted_chat, by_user_id})
    broadcast_from_for_user(by_user_id, {__MODULE__, :deleted_chat, with_user_id})
  end

  @spec save_message(uuid, uuid, map) :: {:ok, map} | {:error, map}
  def save_message(to_user_id, from_user_id, message_data) do
    message_type =
      case message_data do
        %{"question" => question} ->
          case question in Since.Accounts.Profile.contacts() do
            true -> "contact"
            false -> question
          end

        _ ->
          "text"
      end

    if message_type in [
         "meeting_request",
         "meeting_approval",
         "meeting_decline",
         "video",
         "audio",
         "spotify",
         "photo"
       ] do
      m = "message type #{message_type} sent from #{from_user_id} to #{to_user_id}"
      Logger.warning(m)
      Bot.async_post_message(m)
    end

    [user_id_1, user_id_2] = Enum.sort([from_user_id, to_user_id])

    Multi.new()
    |> Multi.run(:chat_new?, fn repo, _changes ->
      case repo.get_by(Chat, user_id_1: user_id_1, user_id_2: user_id_2) do
        %Chat{} = chat ->
          {:ok, {chat, false}}

        nil ->
          chat = %Chat{user_id_1: user_id_1, user_id_2: user_id_2} |> repo.insert!()
          {:ok, {chat, true}}
      end
    end)
    |> Multi.insert(:message, fn %{chat_new?: {%Chat{id: chat_id}, _new}} ->
      message_changeset(%{
        data: message_data,
        chat_id: chat_id,
        from_user_id: from_user_id,
        to_user_id: to_user_id,
        seen: false
      })
    end)
    |> Multi.run(:newly_matched?, fn repo,
                                     %{chat_new?: {%Chat{id: chat_id, matched: matched}, _new}} ->
      case matched do
        true ->
          {:ok, false}

        false ->
          message_exchange =
            Message
            |> where(chat_id: ^chat_id)
            |> where(from_user_id: ^to_user_id)
            |> repo.exists?()

          {:ok, message_exchange}
      end
    end)
    |> Multi.run(:maybe_match, fn repo,
                                  %{chat_new?: {chat, _new}, newly_matched?: newly_matched?} ->
      if newly_matched? do
        chat |> cast(%{matched: true}, [:matched]) |> repo.update()
      else
        {:ok, false}
      end
    end)
    |> Multi.run(:push, fn _repo, %{message: %Message{chat_id: chat_id, id: message_id}} ->
      push_job =
        DispatchJob.new(%{
          "type" => message_type,
          "chat_id" => chat_id,
          "from_user_id" => from_user_id,
          "to_user_id" => to_user_id,
          "message_id" => message_id,
          "data" => message_data
        })

      Oban.insert(push_job)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{chat_new?: {%Chat{} = chat, true}, message: %Message{} = message}} ->
        chat_with_message = %Chat{chat | messages: [message]}
        broadcast_chat(chat_with_message)
        {:ok, message}

      {:ok,
       %{
         chat_new?: {%Chat{} = chat, false},
         message: %Message{} = message,
         newly_matched?: newly_matched?
       }} ->
        broadcast_chat_message(message)
        if newly_matched?, do: broadcast_matched(chat)
        {:ok, message}

      {:error, :message, %Ecto.Changeset{} = changeset, _changes} ->
        {:error, changeset}
    end
  end

  defp message_changeset(attrs) do
    %Message{}
    |> cast(attrs, [:data, :chat_id, :from_user_id, :to_user_id, :seen])
    |> validate_required([:data, :chat_id, :from_user_id, :to_user_id, :seen])
    |> validate_change(:data, fn :data, message_data ->
      case message_data do
        %{"question" => question} ->
          case question in ([
                              "invitation",
                              "acceptance",
                              "meeting_request",
                              "meeting_approval",
                              "meeting_decline",
                              "text",
                              "video",
                              "audio",
                              "spotify",
                              "photo"
                            ] ++
                              Since.Accounts.Profile.contacts()) do
            true -> []
            false -> [message: "unsupported message type"]
          end

        nil ->
          [message: "unrecognized message type"]

        _ ->
          [message: "unrecognized message type"]
      end
    end)
  end

  @spec broadcast_chat(%Chat{}) :: :ok
  defp broadcast_chat(%Chat{user_id_1: uid1, user_id_2: uid2} = chat) do
    message = {__MODULE__, :chat, chat}
    broadcast_for_user(uid1, message)
    broadcast_for_user(uid2, message)
    :ok
  end

  @spec broadcast_chat_message(%Message{}) :: :ok
  defp broadcast_chat_message(%Message{from_user_id: from, to_user_id: to} = chat_message) do
    message = {__MODULE__, :message, chat_message}
    broadcast_for_user(from, message)
    broadcast_for_user(to, message)
    :ok
  end

  defp broadcast_matched(%Chat{user_id_1: uid1, user_id_2: uid2}) do
    message = {__MODULE__, :chat_match, [uid1, uid2]}
    broadcast_for_user(uid1, message)
    broadcast_for_user(uid2, message)
    :ok
  end

  def notify_private_page_available(for_user_id, of_user_id) do
    push_job =
      DispatchJob.new(%{
        "type" => "private_page_available",
        "for_user_id" => for_user_id,
        "of_user_id" => of_user_id
      })

    Oban.insert(push_job)
  end

  @spec mark_message_seen(uuid, uuid) :: :ok | :error
  def mark_message_seen(by_user_id, message_id) do
    Message
    |> where(id: ^message_id)
    |> where(to_user_id: ^by_user_id)
    |> Repo.one()
    |> case do
      nil ->
        :error

      message ->
        message
        |> cast(%{seen: true}, [:seen])
        |> Repo.update()
        |> case do
          {:ok, _} -> :ok
          {:error, _} -> :error
        end
    end
  end
end
