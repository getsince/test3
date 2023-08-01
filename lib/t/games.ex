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
  alias T.Games.{Compliment, ComplimentLimit, ComplimentLimitResetJob}
  alias T.Feeds.{FeedProfile, SeenProfile}
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

  @spec broadcast_for_user(binary, any) :: :ok | {:error, any}
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
  @compliment_limit 25
  @compliment_limit_period 12 * 60 * 60

  @prompts %{
    "meet_for_coffee" => "☕️",
    "potential_friend" => "⚡",
    "party_with" => " 🎉",
    "invite_home" => "🏠",
    "plane_trip" => "✈️",
    "best_smile" => "😌",
    "beautiful_profile" => "🖼",
    "road_trip" => "🚙",
    "best_dressed" => "👄",
    "smells_good" => "✨",
    "human_golden_retriever" => "🐶",
    "eat_pizza" => "🍕",
    "museum_together" => "🤓",
    "yoga_with" => "💪",
    "jazz_together" => "🎶",
    "stand_up_together" => "🎙",
    "cinema_with" => "🎬",
    "show_baby_photos" => "📷",
    "bar_with" => "🍸",
    "tell_about_childhood" => "👶"
  }

  for {tag, _emoji} <- @prompts do
    def render(unquote(tag)), do: dgettext("prompts", unquote(tag))

    for gender <- ["F", "M", "N"] do
      push_tag = tag <> "_push_" <> gender
      def render(unquote(push_tag)), do: dgettext("prompts", unquote(push_tag))
    end
  end

  def render("like"), do: dgettext("prompts", "like")
  def render("like_push_F"), do: dgettext("prompts", "like_push_F")
  def render("like_push_M"), do: dgettext("prompts", "like_push_M")
  def render("like_push_N"), do: dgettext("prompts", "like_push_N")

  def prompts, do: @prompts
  def game_set_count, do: @game_set_count
  def compliment_limit, do: @compliment_limit
  def compliment_limit_period, do: @compliment_limit_period

  ### Game

  def fetch_game(user_id, location, gender, feed_filter) do
    {tag, emoji} = @prompts |> Enum.random()
    random_prompt = {emoji, tag, render(tag)}

    filtered_q = feed_profiles_q(user_id, gender, feed_filter.genders, feed_filter, location)

    Multi.new()
    |> Multi.all(
      :complimenters,
      filtered_complimenters_q(user_id)
      |> order_by(fragment("random()"))
      |> limit(2)
      |> join(:inner, [c], p in FeedProfile, on: c.from_user_id == p.user_id)
      |> select([c, p], %{p | distance: distance_km(^location, p.location)})
    )
    |> Multi.one(:count, filtered_q |> select([p], count(p.user_id)))
    |> Multi.run(:profiles, fn repo, %{complimenters: complimenters, count: count} ->
      if count > 0 do
        required_count = @game_set_count - length(complimenters)
        offset = max(:rand.uniform(count) - required_count, 0)

        profiles =
          filtered_q
          |> offset(^offset)
          |> limit(^required_count)
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
      {:ok, %{profiles: profiles, complimenters: complimenters}} ->
        all_profiles = Enum.shuffle(profiles ++ complimenters)

        if length(all_profiles) > 3 do
          %{"prompt" => random_prompt, "profiles" => all_profiles}
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

  defp complimenter_user_ids_q(user_id) do
    Compliment |> where(to_user_id: ^user_id) |> select([c], c.from_user_id)
  end

  defp not_complimenter_profiles_q(query, user_id) do
    where(query, [p], p.user_id not in subquery(complimenter_user_ids_q(user_id)))
  end

  defp seen_user_ids_q(user_id) do
    SeenProfile |> where(by_user_id: ^user_id) |> select([s], s.user_id)
  end

  defp not_seen_profiles_q(query, user_id) do
    where(query, [p], p.user_id not in subquery(seen_user_ids_q(user_id)))
  end

  defp filtered_profiles_q(user_id, gender, gender_preference) do
    not_hidden_profiles_q()
    |> not_reported_profiles_q(user_id)
    |> not_reporter_profiles_q(user_id)
    |> profiles_that_accept_gender_q(gender)
    |> maybe_gender_preferenced_q(gender_preference)
    |> not_complimented_profiles_q(user_id)
    |> not_complimenter_profiles_q(user_id)
    |> not_seen_profiles_q(user_id)
  end

  defp not_reported_complimenters_q(query, user_id) do
    where(query, [c], c.from_user_id not in subquery(reported_user_ids_q(user_id)))
  end

  defp not_reporter_complimenters_q(query, user_id) do
    where(query, [c], c.from_user_id not in subquery(reporter_user_ids_q(user_id)))
  end

  defp hidden_user_ids_q() do
    FeedProfile |> where(hidden?: true) |> select([p], p.user_id)
  end

  defp not_hidden_complimenters_q(query) do
    where(query, [c], c.from_user_id not in subquery(hidden_user_ids_q()))
  end

  defp not_seen_complimenters_q(query, user_id) do
    where(query, [p], p.from_user_id not in subquery(seen_user_ids_q(user_id)))
  end

  defp filtered_complimenters_q(user_id) do
    Compliment
    |> where(to_user_id: ^user_id)
    |> where(revealed: false)
    |> not_hidden_complimenters_q()
    |> not_reported_complimenters_q(user_id)
    |> not_reporter_complimenters_q(user_id)
    |> not_seen_complimenters_q(user_id)
  end

  ### Compliment

  def list_compliments(user_id, location, premium) do
    Compliment
    |> where(to_user_id: ^user_id)
    |> not_reported_complimenters(user_id)
    |> not_reporter_complimenters(user_id)
    |> order_by(desc: :inserted_at)
    |> join(:inner, [c], p in FeedProfile, on: p.user_id == c.from_user_id)
    |> select([c, p], {c, %{p | distance: distance_km(^location, p.location)}})
    |> Repo.all()
    |> Enum.map(fn {compliment, profile} -> compliment |> maybe_add_profile(premium, profile) end)
  end

  defp not_reported_complimenters(query, user_id),
    do: where(query, [c], c.from_user_id not in subquery(reported_user_ids_q(user_id)))

  defp not_reporter_complimenters(query, user_id),
    do: where(query, [c], c.from_user_id not in subquery(reporter_user_ids_q(user_id)))

  defp maybe_add_profile(compliment, false = _premium, _profile), do: compliment

  defp maybe_add_profile(compliment, true = _premium, profile),
    do: %Compliment{compliment | profile: profile}

  def save_compliment(to_user_id, from_user_id, prompt, seen_ids \\ []) do
    primary_rpc(__MODULE__, :local_save_compliment, [
      from_user_id,
      to_user_id,
      prompt,
      seen_ids
    ])
  end

  @spec local_save_compliment(uuid, uuid, String.t(), [String.t()]) ::
          {:ok, map} | {:error, map}
  def local_save_compliment(from_user_id, to_user_id, prompt, seen_ids) do
    case fetch_compliment_limit(from_user_id) do
      %ComplimentLimit{} = compliment_limit ->
        %ComplimentLimit{user_id: from_user_id}
        |> cast(%{reached: true}, [:reached])
        |> Repo.update()

        return_compliment_limit(compliment_limit)

      nil ->
        m = "compliment #{prompt} sent from #{from_user_id} to #{to_user_id}"
        Logger.warning(m)

        [user_id_1, user_id_2] = Enum.sort([from_user_id, to_user_id])

        now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

        Multi.new()
        |> Multi.insert_all(
          :maybe_seen_profiles,
          SeenProfile,
          seen_ids
          |> Enum.map(fn id ->
            %{by_user_id: from_user_id, user_id: id, inserted_at: now}
          end),
          on_conflict: {:replace, [:inserted_at]},
          conflict_target: [:by_user_id, :user_id]
        )
        |> Multi.run(:compliment_exchange?, fn repo, _changes ->
          previous_compliment =
            Compliment
            |> where(from_user_id: ^to_user_id)
            |> where(to_user_id: ^from_user_id)
            |> limit(1)
            |> repo.all()

          case previous_compliment do
            [%Compliment{} = compliment] -> {:ok, compliment}
            [] -> {:ok, nil}
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
        |> Multi.run(:maybe_insert_compliment_limit, fn repo, _changes ->
          limit_treshold_date =
            DateTime.utc_now()
            |> DateTime.add(-@compliment_limit_period)
            |> DateTime.truncate(:second)

          Compliment
          |> where(from_user_id: ^from_user_id)
          |> where([c], c.inserted_at > ^limit_treshold_date)
          |> repo.aggregate(:count)
          |> case do
            @compliment_limit ->
              m = "#{from_user_id} reached compliment limit"
              Logger.warning(m)
              Bot.async_post_message(m)

              now = DateTime.utc_now()
              insert_compliment_limit(from_user_id, prompt, now, repo)

            _ ->
              {:ok, nil}
          end
        end)
        |> Multi.run(:maybe_insert_chat, fn repo, %{compliment_exchange?: exchange} ->
          if exchange do
            case repo.get_by(Chat, user_id_1: user_id_1, user_id_2: user_id_2) do
              %Chat{id: chat_id} = chat ->
                messages = Message |> where(chat_id: ^chat_id) |> repo.all
                {:ok, %Chat{chat | messages: messages}}

              nil ->
                chat = %Chat{user_id_1: user_id_1, user_id_2: user_id_2} |> repo.insert!()
                {:ok, chat}
            end
          else
            {:ok, nil}
          end
        end)
        |> Multi.run(:profiles, fn repo, _changes ->
          to_user_profile = FeedProfile |> where(user_id: ^to_user_id) |> repo.one!()
          to_user_location = to_user_profile.location

          from_user_profile =
            FeedProfile
            |> where(user_id: ^from_user_id)
            |> select([p], %{p | distance: distance_km(^to_user_location, p.location)})
            |> repo.one!()

          {:ok, %{to_user_profile: to_user_profile, from_user_profile: from_user_profile}}
        end)
        |> Multi.run(:maybe_insert_messages, fn repo,
                                                %{
                                                  maybe_insert_chat: chat,
                                                  compliment_exchange?: exchange,
                                                  compliment: compliment,
                                                  profiles: %{
                                                    to_user_profile: to_user_profile,
                                                    from_user_profile: from_user_profile
                                                  }
                                                } ->
          case {chat, exchange, compliment} do
            {%Chat{id: chat_id}, %Compliment{} = exchange, %Compliment{} = compliment} ->
              messages = [
                compliment_to_message_changeset(exchange, chat_id, to_user_profile),
                compliment_to_message_changeset(compliment, chat_id, from_user_profile)
              ]

              repo.insert_all(Message, messages,
                returning: true,
                on_conflict:
                  {:replace, [:chat_id, :data, :from_user_id, :to_user_id, :inserted_at]},
                conflict_target: [:id]
              )
              |> case do
                {2, messages} -> {:ok, messages}
                true -> {:error, :messages_not_inserted}
              end

            _ ->
              {:ok, nil}
          end
        end)
        |> Multi.run(:maybe_mark_compliment_revealed, fn repo,
                                                         %{compliment_exchange?: exchange} ->
          if exchange do
            exchange |> cast(%{revealed: true}, [:revealed]) |> repo.update()
          else
            {:ok, nil}
          end
        end)
        |> Multi.run(:push, fn _repo,
                               %{
                                 compliment_exchange?: exchange,
                                 compliment: %Compliment{id: compliment_id},
                                 profiles: %{
                                   to_user_profile: to_user_profile,
                                   from_user_profile: from_user_profile
                                 }
                               } ->
          push_job =
            if exchange do
              DispatchJob.new(%{
                "type" => "compliment_revealed",
                "from_user_id" => from_user_id,
                "to_user_id" => to_user_id,
                "compliment_id" => compliment_id,
                "prompt" => prompt,
                "emoji" => @prompts[prompt] || "❤️"
              })
            else
              DispatchJob.new(%{
                "type" => "compliment",
                "to_user_id" => to_user_id,
                "compliment_id" => compliment_id,
                "prompt" => prompt,
                "emoji" => @prompts[prompt] || "❤️",
                "premium" => to_user_profile.premium,
                "from_user_name" => from_user_profile.name,
                "from_user_gender" => from_user_profile.gender
              })
            end

          Oban.insert(push_job)
        end)
        |> Repo.transaction()
        |> case do
          {:ok,
           %{
             compliment_exchange?: nil,
             compliment: %Compliment{} = compliment,
             profiles: %{to_user_profile: to_user_profile, from_user_profile: from_user_profile}
           }} ->
            full_compliment =
              compliment |> maybe_add_profile(to_user_profile.premium, from_user_profile)

            broadcast_compliment(full_compliment)

            {:ok, full_compliment}

          {:ok,
           %{
             maybe_insert_chat: %Chat{messages: maybe_previous_messages} = chat,
             maybe_insert_messages: messages
           }} ->
            m = "compliments exchanged between #{from_user_id} and #{to_user_id}"
            Logger.warning(m)
            Bot.async_post_message(m)

            chat_with_messages =
              case maybe_previous_messages do
                nil -> %Chat{chat | messages: messages}
                _ -> %Chat{chat | messages: maybe_previous_messages ++ messages}
              end

            broadcast_chat(chat_with_messages)
            {:ok, chat_with_messages}

          {:error, :compliment, %Ecto.Changeset{} = changeset, _changes} ->
            {:error, changeset}
        end
    end
  end

  def fetch_compliment_limit(user_id),
    do: ComplimentLimit |> where(user_id: ^user_id) |> Repo.one()

  defp return_compliment_limit(%ComplimentLimit{timestamp: timestamp}) do
    reset_timestamp = timestamp |> DateTime.add(@compliment_limit_period)
    {:error, reset_timestamp}
  end

  def insert_compliment_limit(user_id, prompt, reference, repo \\ T.Repo) do
    now = reference |> DateTime.truncate(:second)
    reset_at = DateTime.add(now, @compliment_limit_period)

    reset_job = ComplimentLimitResetJob.new(%{"user_id" => user_id}, scheduled_at: reset_at)

    Multi.new()
    |> Multi.insert(:limit, %ComplimentLimit{user_id: user_id, timestamp: now, prompt: prompt})
    |> Oban.insert(:reset, reset_job)
    |> repo.transaction()
  end

  defp compliment_changeset(attrs) do
    %Compliment{}
    |> cast(attrs, [:prompt, :from_user_id, :to_user_id, :seen, :revealed])
    |> validate_required([:prompt, :from_user_id, :to_user_id, :seen, :revealed])
    |> validate_change(:prompt, fn :prompt, prompt ->
      if prompt in (Map.keys(@prompts) ++ ["like"]) do
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
         chat_id,
         from_user_profile
       ) do
    data = %{"question" => "compliment", "prompt" => prompt, "gender" => from_user_profile.gender}

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

  ### Compliment Limit

  @spec local_reset_compliment_limit(%ComplimentLimit{}) :: :ok
  def local_reset_compliment_limit(%ComplimentLimit{user_id: user_id} = limit) do
    Multi.new()
    |> Multi.delete_all(:delete_compliment_limit, ComplimentLimit |> where(user_id: ^user_id))
    |> maybe_schedule_push(limit)
    |> Repo.transaction()

    :ok
  end

  defp maybe_schedule_push(multi, %ComplimentLimit{
         user_id: user_id,
         prompt: prompt,
         reached: true
       }) do
    multi
    |> Multi.run(:push, fn _repo, _changes ->
      push_job =
        DispatchJob.new(%{
          "type" => "compliment_limit_reset",
          "user_id" => user_id,
          "prompt" => prompt
        })

      Oban.insert(push_job)
    end)
  end

  defp maybe_schedule_push(multi, _compliment_limit), do: multi
end
