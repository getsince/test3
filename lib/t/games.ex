defmodule T.Games do
  @moduledoc "Games for the app."

  import Ecto.{Query, Changeset}
  alias Ecto.Multi
  import Geo.PostGIS
  import T.Gettext
  require Logger

  import T.Cluster, only: [primary_rpc: 3]

  alias T.{Repo, Bot}

  alias T.Accounts.{UserReport, GenderPreference}
  alias T.Chats.{Chat, Message}
  alias T.Games.Compliment
  alias T.Feeds.FeedProfile
  alias T.PushNotifications.DispatchJob

  @type uuid :: Ecto.UUID.t()

  ### PubSub

  # TODO optimise pubsub:
  # instead of single topic, use `up-to-filter` with each subscriber providing a value up to which
  # they are subscribed, and if the event is below that value -> send it, if not -> don't send it

  @pubsub T.PubSub
  @topic "__f"

  @spec subscribe_for_user(binary) :: :ok | {:error, {:already_registered, pid}}
  def subscribe_for_user(user_id) do
    Phoenix.PubSub.subscribe(@pubsub, pubsub_user_topic(user_id))
  end

  defp pubsub_user_topic(user_id) when is_binary(user_id) do
    @topic <> ":u:" <> String.downcase(user_id)
  end

  def broadcast_for_user(user_id, message) do
    Phoenix.PubSub.broadcast(@pubsub, pubsub_user_topic(user_id), message)
  end

  defmacrop distance_km(location1, location2) do
    quote do
      fragment(
        "round(? / 1000)::int",
        st_distance_in_meters(unquote(location1), unquote(location2))
      )
    end
  end

  @game_set_count 16
  @game_profiles_recency_limit 180 * 24 * 60 * 60

  @prompts %{"coffee_meet" => "☕️", "bro_meet" => "⚡️"}

  for {tag, _emoji} <- @prompts do
    def render(unquote(tag)), do: dgettext("prompts", unquote(tag))
    push_tag = tag <> "_push"
    def render(unquote(push_tag)), do: dgettext("prompts", unquote(push_tag))
  end

  def prompts, do: @prompts
  def game_set_count, do: @game_set_count

  ### Game

  def fetch_game(user_id, location, gender, feed_filter) do
    {tag, emoji} = @prompts |> Enum.random()
    random_prompt = {emoji, tag, render(tag)}

    filtered_q = feed_profiles_q(user_id, gender, feed_filter.genders, feed_filter, location)

    Multi.new()
    |> Multi.one(:count, filtered_q |> select([p], count(p.user_id)))
    |> Multi.run(:profiles, fn repo, %{count: count} ->
      if count > 0 do
        offset = max(:rand.uniform(count) - @game_set_count, 0)

        profiles =
          filtered_q
          |> offset(^offset)
          |> limit(@game_set_count)
          |> order_by(fragment("location <-> ?::geometry", ^location))
          |> select([p], %{p | distance: distance_km(^location, p.location)})
          |> repo.all()

        {:ok, profiles}
      else
        {:ok, []}
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{profiles: profiles}} ->
        if length(profiles) > 3 do
          %{"prompt" => random_prompt, "profiles" => profiles}
        else
          nil
        end
    end
  end

  defp maybe_apply_age_filters(query, feed_filter) do
    query
    |> maybe_apply_min_age_filer(feed_filter.min_age)
    |> maybe_apply_max_age_filer(feed_filter.max_age)
  end

  defp maybe_apply_min_age_filer(query, min_age) do
    if min_age do
      where(query, [p], p.birthdate <= fragment("now() - ? * interval '1y'", ^min_age))
    else
      query
    end
  end

  defp maybe_apply_max_age_filer(query, max_age) do
    if max_age do
      where(query, [p], p.birthdate >= fragment("now() - ? * interval '1y'", ^max_age))
    else
      query
    end
  end

  defp maybe_apply_distance_filter(query, location, distance) do
    if distance do
      meters = distance * 1000
      where(query, [p], st_dwithin_in_meters(^location, p.location, ^meters))
    else
      query
    end
  end

  defp feed_profiles_q(user_id, gender, gender_preference, feed_filter, location) do
    # TODO
    treshold_date = DateTime.utc_now() |> DateTime.add(-@game_profiles_recency_limit, :second)

    filtered_profiles_q(user_id, gender, gender_preference)
    |> where([p], p.user_id != ^user_id)
    |> where([p], p.last_active > ^treshold_date)
    |> maybe_apply_age_filters(feed_filter)
    |> maybe_apply_distance_filter(location, feed_filter.distance)
  end

  defp reported_user_ids_q(user_id) do
    UserReport |> where(from_user_id: ^user_id) |> select([r], r.on_user_id)
  end

  defp not_reported_profiles_q(query, user_id) do
    where(query, [p], p.user_id not in subquery(reported_user_ids_q(user_id)))
  end

  defp reporter_user_ids_q(user_id) do
    UserReport |> where(on_user_id: ^user_id) |> select([r], r.from_user_id)
  end

  defp not_reporter_profiles_q(query, user_id) do
    where(query, [p], p.user_id not in subquery(reporter_user_ids_q(user_id)))
  end

  defp not_hidden_profiles_q do
    where(FeedProfile, hidden?: false)
  end

  defp profiles_that_accept_gender_q(query, gender) do
    if gender do
      join(query, :inner, [p], gp in GenderPreference,
        on: gp.gender == ^gender and p.user_id == gp.user_id
      )
    else
      query
    end
  end

  defp maybe_gender_preferenced_q(query, _no_preferences = []), do: query

  defp maybe_gender_preferenced_q(query, gender_preference) do
    where(query, [p], p.gender in ^gender_preference)
  end

  defp complimented_user_ids_q(user_id) do
    Compliment |> where(from_user_id: ^user_id) |> select([c], c.to_user_id)
  end

  defp not_complimented_profiles_q(query, user_id) do
    where(query, [p], p.user_id not in subquery(complimented_user_ids_q(user_id)))
  end

  defp filtered_profiles_q(user_id, gender, gender_preference) do
    not_hidden_profiles_q()
    |> not_reported_profiles_q(user_id)
    |> not_reporter_profiles_q(user_id)
    |> profiles_that_accept_gender_q(gender)
    |> maybe_gender_preferenced_q(gender_preference)
    |> not_complimented_profiles_q(user_id)
  end

  ### Compliment

  def list_compliments(user_id) do
    Compliment
    |> where(to_user_id: ^user_id)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
    |> Enum.map(fn c ->
      %Compliment{
        c
        | text: render(c.prompt),
          emoji: @prompts[c.prompt],
          push_text: render(c.prompt <> "_push")
      }
    end)
  end

  def save_compliment(to_user_id, from_user_id, prompt) do
    primary_rpc(__MODULE__, :local_save_compliment, [
      from_user_id,
      to_user_id,
      prompt
    ])
  end

  @spec local_save_compliment(uuid, uuid, String.t()) ::
          {:ok, map} | {:error, map}
  def local_save_compliment(from_user_id, to_user_id, prompt) do
    m = "compliment #{prompt} sent from #{from_user_id} to #{to_user_id}"
    Logger.warn(m)
    Bot.async_post_message(m)

    [user_id_1, user_id_2] = Enum.sort([from_user_id, to_user_id])

    Multi.new()
    |> Multi.run(:compliment_exchange?, fn repo, _changes ->
      case repo.get_by(Compliment, from_user_id: to_user_id, to_user_id: from_user_id) do
        %Compliment{} = compliment -> {:ok, compliment}
        nil -> {:ok, nil}
      end
    end)
    |> Multi.insert(:compliment, fn %{compliment_exchange?: exchange} ->
      compliment_changeset(%{
        prompt: prompt,
        from_user_id: from_user_id,
        to_user_id: to_user_id,
        seen: false,
        revealed: not is_nil(exchange)
      })
    end)
    |> Multi.run(:maybe_insert_chat, fn repo, %{compliment_exchange?: exchange} ->
      if exchange do
        case repo.get_by(Chat, user_id_1: user_id_1, user_id_2: user_id_2) do
          %Chat{} = chat ->
            {:ok, chat}

          nil ->
            chat = %Chat{user_id_1: user_id_1, user_id_2: user_id_2} |> repo.insert!()
            {:ok, chat}
        end
      else
        {:ok, nil}
      end
    end)
    |> Multi.run(:maybe_insert_messages, fn repo,
                                            %{
                                              maybe_insert_chat: chat,
                                              compliment_exchange?: exchange,
                                              compliment: compliment
                                            } ->
      case {chat, exchange, compliment} do
        {%Chat{id: chat_id}, %Compliment{} = exchange, %Compliment{} = compliment} ->
          messages =
            [exchange, compliment]
            |> Enum.map(fn c -> compliment_to_message_changeset(c, chat_id) end)

          repo.insert_all(Message, messages, returning: true)
          |> case do
            {2, messages} -> {:ok, messages}
            true -> {:error, :messages_not_inserted}
          end

        _ ->
          {:ok, nil}
      end
    end)
    |> Multi.run(:maybe_mark_compliment_revealed, fn repo, %{compliment_exchange?: exchange} ->
      if exchange do
        exchange |> cast(%{revealed: true}, [:revealed]) |> repo.update()
      else
        {:ok, nil}
      end
    end)
    |> Multi.run(:push, fn _repo,
                           %{
                             compliment_exchange?: exchange,
                             compliment: %Compliment{id: compliment_id}
                           } ->
      push_job =
        if exchange do
          DispatchJob.new(%{
            "type" => "compliment_revealed",
            "from_user_id" => from_user_id,
            "to_user_id" => to_user_id,
            "compliment_id" => compliment_id,
            "prompt" => prompt
          })
        else
          DispatchJob.new(%{
            "type" => "compliment",
            "from_user_id" => from_user_id,
            "to_user_id" => to_user_id,
            "compliment_id" => compliment_id,
            "prompt" => prompt
          })
        end

      Oban.insert(push_job)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{compliment_exchange?: nil, compliment: %Compliment{} = compliment}} ->
        broadcast_compliment(compliment)
        {:ok, compliment}

      {:ok, %{maybe_insert_chat: %Chat{} = chat, maybe_insert_messages: messages}} ->
        chat_with_messages = %Chat{chat | messages: messages}
        broadcast_chat(chat_with_messages)
        {:ok, chat_with_messages}

      {:error, :compliment, %Ecto.Changeset{} = changeset, _changes} ->
        {:error, changeset}
    end
  end

  defp compliment_changeset(attrs) do
    %Compliment{}
    |> cast(attrs, [:prompt, :from_user_id, :to_user_id, :seen, :revealed])
    |> validate_required([:prompt, :from_user_id, :to_user_id, :seen, :revealed])
    |> validate_change(:prompt, fn :prompt, prompt ->
      if prompt in Map.keys(@prompts) do
        []
      else
        [compliment: "unrecognized prompt"]
      end
    end)
  end

  defp compliment_to_message_changeset(
         %Compliment{
           id: id,
           from_user_id: from_user_id,
           to_user_id: to_user_id,
           prompt: prompt,
           inserted_at: inserted_at
         },
         chat_id
       ) do
    data = %{
      "question" => "compliment",
      "prompt" => prompt,
      "emoji" => @prompts[prompt],
      "value" => render(prompt),
      "push_text" => render(prompt <> "_push")
    }

    %{
      id: id,
      chat_id: chat_id,
      data: data,
      from_user_id: from_user_id,
      to_user_id: to_user_id,
      inserted_at: inserted_at
    }
  end

  @spec broadcast_chat(%Chat{}) :: :ok
  defp broadcast_chat(%Chat{user_id_1: uid1, user_id_2: uid2} = chat) do
    message = {__MODULE__, :chat, chat}
    broadcast_for_user(uid1, message)
    broadcast_for_user(uid2, message)
    :ok
  end

  @spec broadcast_compliment(%Compliment{}) :: :ok
  defp broadcast_compliment(%Compliment{to_user_id: to} = compliment) do
    message = {__MODULE__, :compliment, compliment}
    broadcast_for_user(to, message)
    :ok
  end

  @spec mark_compliment_seen(uuid, uuid) :: :ok | :error
  def mark_compliment_seen(by_user_id, compliment_id) do
    primary_rpc(__MODULE__, :local_mark_compliment_seen, [by_user_id, compliment_id])
  end

  @spec local_mark_compliment_seen(uuid, uuid) :: :ok | :error
  def local_mark_compliment_seen(by_user_id, compliment_id) do
    Compliment
    |> where(id: ^compliment_id)
    |> where(to_user_id: ^by_user_id)
    |> Repo.one()
    |> case do
      nil ->
        :error

      compliment ->
        compliment
        |> cast(%{seen: true}, [:seen])
        |> Repo.update()
        |> case do
          {:ok, _} -> :ok
          {:error, _} -> :error
        end
    end
  end
end
