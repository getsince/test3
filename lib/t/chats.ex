defmodule T.Chats do
  @moduledoc "Chats"

  import Ecto.{Query, Changeset}
  alias Ecto.Multi
  import Geo.PostGIS

  require Logger

  import T.Cluster, only: [primary_rpc: 3]

  alias T.Repo
  alias T.Chats.{Chat, Message}
  alias T.Feeds.{FeedProfile, SeenProfile}
  alias T.PushNotifications.DispatchJob

  @type uuid :: Ecto.UUID.t()

  # - PubSub

  @pubsub T.PubSub
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

  defmacrop distance_km(location1, location2) do
    quote do
      fragment(
        "round(? / 1000)::int",
        st_distance_in_meters(unquote(location1), unquote(location2))
      )
    end
  end

  def list_chats(user_id, location) do
    Chat
    |> where([c], c.user_id_1 == ^user_id or c.user_id_2 == ^user_id)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
    |> preload_chat_profiles(user_id, location)
    |> preload_messages()
  end

  # TODO cleanup
  defp preload_chat_profiles(chats, user_id, location) do
    mate_chats =
      Map.new(chats, fn chat ->
        [mate_id] = [chat.user_id_1, chat.user_id_2] -- [user_id]
        {mate_id, chat}
      end)

    mates = Map.keys(mate_chats)

    profiles =
      FeedProfile
      |> where([p], p.user_id in ^mates)
      |> select([p], %{p | distance: distance_km(^location, p.location)})
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
      |> Repo.all()

    Enum.map(chats, fn chat ->
      %Chat{chat | messages: Enum.filter(messages, fn m -> m.chat_id == chat.id end)}
    end)
  end

  # TODO decline invitation

  @spec delete_chat(uuid, uuid) :: boolean
  def delete_chat(by_user_id, chat_id) do
    primary_rpc(__MODULE__, :local_delete_chat, [by_user_id, chat_id])
  end

  @doc false
  def local_delete_chat(by_user_id, chat_id) do
    Logger.warn("#{by_user_id} deletes chat-id=#{chat_id}")

    Multi.new()
    |> Multi.run(:delete_chat, fn _repo, _changes ->
      Chat
      |> where(id: ^chat_id)
      |> where([c], c.user_id_1 == ^by_user_id or c.user_id_2 == ^by_user_id)
      |> select([c], [c.user_id_1, c.user_id_2])
      |> Repo.delete_all()
      |> case do
        {1, [user_ids]} -> {:ok, user_ids}
        {0, _} -> {:error, :chat_not_found}
      end
    end)
    |> mark_chatters_seen_m()
    |> Repo.transaction()
    |> case do
      {:ok, %{delete_chat: user_ids}} when is_list(user_ids) ->
        [mate] = user_ids -- [by_user_id]
        notify_delete_chat(by_user_id, mate, chat_id)
        _deleted_chat? = true

      {:error, :delete_chat, :chat_not_found, _changes} ->
        _deleted_chat? = false
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

  defp notify_delete_chat(by_user_id, mate_id, chat_id) do
    broadcast_for_user(mate_id, {__MODULE__, :deleted_chat, chat_id})
    broadcast_from_for_user(by_user_id, {__MODULE__, :deleted_chat, chat_id})
  end

  @spec save_message(uuid, uuid, map) :: {:ok, map, map} | {:error, map}
  def save_message(to_user_id, from_user_id, message_data) do
    primary_rpc(__MODULE__, :local_save_message, [
      from_user_id,
      to_user_id,
      message_data
    ])
  end

  @spec local_save_message(uuid, uuid, map) ::
          {:ok, map, map} | {:error, map}
  def local_save_message(from_user_id, to_user_id, message_data) do
    message_type =
      case message_data do
        %{"question" => question} ->
          case question in T.Accounts.Profile.contacts() do
            true -> "contact"
            false -> question
          end

        _ ->
          "text"
      end

    [user_id_1, user_id_2] = Enum.sort([from_user_id, to_user_id])

    Multi.new()
    |> Multi.run(:chat, fn repo, _changes ->
      case repo.get_by(Chat, user_id_1: user_id_1, user_id_2: user_id_2) do
        %Chat{} = chat -> {:ok, chat}
        nil -> %Chat{user_id_1: user_id_1, user_id_2: user_id_2} |> repo.insert()
      end
    end)
    |> Multi.insert(:message, fn %{chat: %Chat{id: chat_id}} ->
      message_changeset(%{
        data: message_data,
        chat_id: chat_id,
        from_user_id: from_user_id,
        to_user_id: to_user_id,
        seen: false
      })
    end)
    |> Multi.run(:push, fn _repo, %{message: %Message{chat_id: chat_id, id: message_id}} ->
      push_job =
        DispatchJob.new(%{
          "type" => message_type,
          "chat_id" => chat_id,
          "from_user_id" => from_user_id,
          "to_user_id" => to_user_id,
          "message_id" => message_id
        })

      Oban.insert(push_job)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{chat: %Chat{} = chat, message: %Message{} = message}} ->
        broadcast_chat_message(message)
        {:ok, chat, message}

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
                              "text",
                              "video",
                              "audio",
                              "spotify",
                              "photo"
                            ] ++
                              T.Accounts.Profile.contacts()) do
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

  @spec broadcast_chat_message(%Message{}) :: :ok
  defp broadcast_chat_message(%Message{from_user_id: from, to_user_id: to} = chat_message) do
    message = {__MODULE__, :message, chat_message}
    broadcast_for_user(from, message)
    broadcast_for_user(to, message)
    :ok
  end

  @spec mark_message_seen(uuid, uuid) :: :ok | :error
  def mark_message_seen(by_user_id, message_id) do
    primary_rpc(__MODULE__, :local_mark_message_seen, [by_user_id, message_id])
  end

  @spec local_mark_message_seen(uuid, uuid) :: :ok | :error
  def local_mark_message_seen(by_user_id, message_id) do
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
