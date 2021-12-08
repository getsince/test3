defmodule T.Feeds do
  @moduledoc "Feeds for alternative app. Invites & Calls."

  import Ecto.Query
  import Ecto.Changeset
  import Geo.PostGIS

  require Logger

  alias T.Repo
  # alias T.Bot
  # alias T.Accounts
  alias T.Accounts.{Profile, UserReport, GenderPreference}
  alias T.Matches.{Match, Like, ExpiredMatch}
  # alias T.Calls
  alias T.Feeds.{FeedProfile, SeenProfile, FeededProfile, FeedFilter, LiveSession, LiveInvite}
  alias T.PushNotifications.DispatchJob

  ### PubSub

  # TODO optimise pubsub:
  # instead of single topic, use `up-to-filter` with each subscriber providing a value up to which
  # they are subscribed, and if the event is below that value -> send it, if not -> don't send it

  @pubsub T.PubSub
  @topic "__f"

  def subscribe_for_live_sessions, do: subscribe(live_topic())
  defp live_topic, do: "__live:"

  def subscribe_for_mode_change, do: subscribe(mode_change_topic())
  defp mode_change_topic, do: "__mode_change:"

  def subscribe_for_user(user_id) do
    Phoenix.PubSub.subscribe(@pubsub, pubsub_user_topic(user_id))
  end

  defp notify_subscribers(%LiveSession{user_id: user_id} = session, :live = event) do
    broadcast_from(live_topic(), {__MODULE__, event, user_id})
    session
  end

  defp notify_subscribers(:mode_change, event) do
    broadcast_from(mode_change_topic(), {__MODULE__, [:mode_change, event]})
  end

  defp notify_subscribers({:error, _multi, _reason, _changes} = fail, _event), do: fail
  defp notify_subscribers({:error, _reason} = fail, _event), do: fail

  # defp broadcast(topic, message) do
  #   Phoenix.PubSub.broadcast(@pubsub, topic, message)
  # end

  defp broadcast_from(topic, message) do
    Phoenix.PubSub.broadcast_from(@pubsub, self(), topic, message)
  end

  defp pubsub_user_topic(user_id) when is_binary(user_id) do
    @topic <> ":u:" <> String.downcase(user_id)
  end

  defp broadcast_for_user(user_id, message) do
    Phoenix.PubSub.broadcast(@pubsub, pubsub_user_topic(user_id), message)
  end

  defp subscribe(topic) do
    Phoenix.PubSub.subscribe(@pubsub, topic)
  end

  ### Likes

  # TODO accept cursor
  @spec list_received_likes(Ecto.UUID.t()) :: [%FeedProfile{}]
  def list_received_likes(user_id) do
    profiles_q = not_reported_profiles_q(user_id)

    Like
    |> where(user_id: ^user_id)
    |> where([l], is_nil(l.declined))
    |> not_match1_profiles_q(user_id)
    |> not_match2_profiles_q(user_id)
    |> order_by(desc: :inserted_at)
    |> join(:inner, [l], p in subquery(profiles_q), on: p.user_id == l.by_user_id)
    |> select([l, p], p)
    |> Repo.all()
  end

  defp match_user1_ids_q(user_id) do
    Match |> where(user_id_1: ^user_id) |> select([m], m.user_id_2)
  end

  defp match_user2_ids_q(user_id) do
    Match |> where(user_id_2: ^user_id) |> select([m], m.user_id_1)
  end

  defp not_match1_profiles_q(query, user_id) do
    where(query, [p], p.by_user_id not in subquery(match_user1_ids_q(user_id)))
  end

  defp not_match2_profiles_q(query, user_id) do
    where(query, [p], p.by_user_id not in subquery(match_user2_ids_q(user_id)))
  end

  ### Live Feed

  # TODO change
  def since_live_time_text() do
    %{
      "en" => "Come to Since Live every Thursday from 19:00 to 21:00, it will be great ✌️",
      "ru" => "Приходи на Since Live каждый четверг с 19:00 до 21:00, будет классно ✌️"
    }
  end

  def is_now_live_mode() do
    day_of_week = Date.utc_today() |> Date.day_of_week()
    hour = DateTime.utc_now().hour
    # minute = DateTime.utc_now().minute

    # true
    # minute < 25
    day_of_week == 4 && (hour == 16 || hour == 17)
  end

  @spec live_mode_start_and_end_dates :: {DateTime.t(), DateTime.t()}
  def live_mode_start_and_end_dates() do
    session_start = DateTime.new!(Date.utc_today(), Time.new!(18, 0, 0))
    session_end = DateTime.new!(Date.utc_today(), Time.new!(16, 0, 0))
    {session_start, session_end}
  end

  def notify_live_mode_start() do
    notify_subscribers(:mode_change, :start)
    DispatchJob.new(%{"type" => "live_mode_started"}) |> Oban.insert()
  end

  def notify_live_mode_end() do
    notify_subscribers(:mode_change, :end)
    DispatchJob.new(%{"type" => "live_mode_ended"}) |> Oban.insert()
  end

  def clear_live_tables() do
    # TODO tg bots
    LiveInvite |> Repo.delete_all()
    LiveSession |> Repo.delete_all()
  end

  # TODO test pubsub
  def maybe_activate_session(user_id) do
    is_already_live =
      LiveSession |> where(user_id: ^user_id) |> select([s], count()) |> Repo.all()

    case is_already_live do
      [0] ->
        Logger.warn("user #{user_id} activated session")
        # TODO bot

        %LiveSession{user_id: user_id}
        |> Repo.insert!(on_conflict: :replace_all, conflict_target: :user_id)
        |> notify_subscribers(:live)

        maybe_schedule_push_to_matches(user_id)

      _ ->
        nil
    end
  end

  defp maybe_schedule_push_to_matches(user_id) do
    Match
    |> where([m], m.user_id_1 == ^user_id or m.user_id_2 == ^user_id)
    |> select([m], {m.user_id_1, m.user_id_2})
    |> Repo.all()
    |> Enum.map(fn {user_id_1, user_id_2} ->
      mate_id = [user_id_1, user_id_2] -- [user_id]

      job =
        DispatchJob.new(%{
          "type" => "match_went_live",
          "user_id" => user_id,
          "for_user_id" => mate_id
        })

      Oban.insert(job)
    end)
  end

  @type feed_cursor :: String.t()

  @spec fetch_live_feed(
          Ecto.UUID.t(),
          pos_integer,
          feed_cursor | nil
        ) ::
          {[%FeedProfile{}], feed_cursor}
  def fetch_live_feed(user_id, count, feed_cursor) do
    profiles_q = filtered_live_profiles_q(user_id)

    feed_items =
      live_sessions_q(user_id, feed_cursor)
      |> join(:inner, [s], p in subquery(profiles_q), on: s.user_id == p.user_id)
      |> limit(^count)
      |> select([s, p], {s, p})
      |> Repo.all()

    feed_cursor =
      if last = List.last(feed_items) do
        {%LiveSession{flake: last_flake}, _feed_profile} = last
        last_flake
      else
        feed_cursor
      end

    feed_profiles = feed_items |> Enum.map(fn {_s, p} -> p end)

    {feed_profiles, feed_cursor}
  end

  def get_live_feed_profile(for_user_id, mate) do
    not_hidden_profiles_q()
    |> not_reported_profiles_q(for_user_id)
    |> where(user_id: ^mate)
    |> Repo.one()
  end

  @spec live_sessions_q(Ecto.UUID.t(), String.t() | nil) :: Ecto.Query.t()
  defp live_sessions_q(user_id, nil) do
    LiveSession
    |> order_by([s], asc: s.flake)
    |> where([s], s.user_id != ^user_id)
  end

  defp live_sessions_q(user_id, last_flake) do
    user_id
    |> live_sessions_q(nil)
    |> where([s], s.flake > ^last_flake)
  end

  defp invited_user_ids_q(user_id) do
    LiveInvite |> where(by_user_id: ^user_id) |> select([l], l.user_id)
  end

  defp not_invited_profiles_q(query, user_id) do
    where(query, [p], p.user_id not in subquery(invited_user_ids_q(user_id)))
  end

  defp inviter_user_ids_q(user_id) do
    LiveInvite |> where(user_id: ^user_id) |> select([l], l.by_user_id)
  end

  defp not_inviter_profiles_q(query, user_id) do
    where(query, [p], p.user_id not in subquery(inviter_user_ids_q(user_id)))
  end

  defp not_match1_live_profiles_q(query, user_id) do
    where(query, [p], p.user_id not in subquery(match_user1_ids_q(user_id)))
  end

  defp not_match2_live_profiles_q(query, user_id) do
    where(query, [p], p.user_id not in subquery(match_user2_ids_q(user_id)))
  end

  defp filtered_live_profiles_q(user_id) do
    not_hidden_profiles_q()
    |> not_reported_profiles_q(user_id)
    |> not_invited_profiles_q(user_id)
    |> not_inviter_profiles_q(user_id)
    |> not_match1_live_profiles_q(user_id)
    |> not_match2_live_profiles_q(user_id)
  end

  def live_invite_user(by_user_id, user_id) do
    %LiveInvite{by_user_id: by_user_id, user_id: user_id}
    |> Repo.insert!(on_conflict: :replace_all, conflict_target: [:by_user_id, :user_id])

    notify_invited_user(by_user_id, user_id)
  end

  defp notify_invited_user(by_user_id, user_id) do
    broadcast_for_user(user_id, {__MODULE__, :live_invited, %{by_user_id: by_user_id}})
    schedule_invited_push(by_user_id, user_id)
  end

  defp schedule_invited_push(by_user_id, user_id) do
    job =
      DispatchJob.new(%{"type" => "live_invite", "by_user_id" => by_user_id, "user_id" => user_id})

    Oban.insert(job)
  end

  def list_received_invites(user_id) do
    profiles_q = not_reported_profiles_q(user_id)

    LiveInvite
    |> where(user_id: ^user_id)
    |> order_by(desc: :inserted_at)
    |> join(:inner, [l], p in subquery(profiles_q), on: p.user_id == l.by_user_id)
    |> select([l, p], p)
    |> Repo.all()
  end

  ### Normal Feed

  @spec fetch_feed(
          Ecto.UUID.t(),
          Geo.Point.t(),
          String.t(),
          %FeedFilter{},
          pos_integer,
          feed_cursor | nil
        ) ::
          {[%FeedProfile{}], feed_cursor}
  def fetch_feed(user_id, location, gender, feed_filter, count, feed_cursor) do
    if feed_cursor == nil do
      empty_feeded_profiles(user_id)
    end

    feed_profiles = continue_feed(user_id, location, gender, feed_filter, count)

    mark_profiles_feeded(user_id, feed_profiles)

    feed_cursor =
      if length(feed_profiles) > 0 do
        "non-nil"
      else
        feed_cursor
      end

    {feed_profiles, feed_cursor}
  end

  defp continue_feed(user_id, location, gender, feed_filter, count) do
    %FeedFilter{
      genders: gender_preferences,
      min_age: min_age,
      max_age: max_age,
      distance: distance
    } = feed_filter

    feeded = FeededProfile |> where(for_user_id: ^user_id) |> select([s], s.user_id)

    most_liked_count = count - div(count, 2)

    most_liked =
      most_liked_q(user_id, gender, gender_preferences, feeded)
      |> maybe_apply_age_filters(min_age, max_age)
      |> maybe_apply_distance_filter(location, distance)
      |> limit(^most_liked_count)
      |> Repo.all()

    filter_out_ids = Enum.map(most_liked, fn p -> p.user_id end)

    most_recent_count = count - length(most_liked)

    most_recent =
      most_recent_q(user_id, gender, gender_preferences, feeded, filter_out_ids)
      |> maybe_apply_age_filters(min_age, max_age)
      |> maybe_apply_distance_filter(location, distance)
      |> limit(^most_recent_count)
      |> Repo.all()

    most_liked ++ most_recent
  end

  defp most_liked_q(user_id, gender, gender_preferences, feeded) do
    feed_profiles_q(user_id, gender, gender_preferences)
    |> where([p], p.user_id not in subquery(feeded))
    |> order_by(desc: :like_ratio)
  end

  defp most_recent_q(user_id, gender, gender_preferences, feeded, filter_out_ids) do
    feed_profiles_q(user_id, gender, gender_preferences)
    |> where([p], p.user_id not in subquery(feeded))
    |> where([p], p.user_id not in ^filter_out_ids)
    |> order_by(desc: :last_active)
  end

  defp maybe_apply_age_filters(query, min_age, max_age) do
    query
    |> maybe_apply_min_age_filer(min_age)
    |> maybe_apply_max_age_filer(max_age)
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

  defp empty_feeded_profiles(user_id) do
    FeededProfile |> where(for_user_id: ^user_id) |> Repo.delete_all()
  end

  defp mark_profiles_feeded(for_user_id, feed_profiles) do
    data =
      Enum.map(feed_profiles, fn p ->
        %{for_user_id: for_user_id, user_id: p.user_id}
      end)

    Repo.insert_all(FeededProfile, data, on_conflict: :nothing)
  end

  def get_feed_filter(user_id) do
    genders = T.Accounts.list_gender_preferences(user_id)

    {min_age, max_age, distance} =
      Profile
      |> where(user_id: ^user_id)
      |> select([p], {p.min_age, p.max_age, p.distance})
      |> Repo.one!()

    %FeedFilter{genders: genders, min_age: min_age, max_age: max_age, distance: distance}
  end

  @spec get_mate_feed_profile(Ecto.UUID.t()) :: %FeedProfile{} | nil
  def get_mate_feed_profile(user_id) do
    not_hidden_profiles_q()
    |> where(user_id: ^user_id)
    |> Repo.one()
  end

  defp feed_profiles_q(user_id, gender, gender_preference) do
    treshold_date = DateTime.utc_now() |> DateTime.add(-60 * 24 * 60 * 60, :second)

    filtered_profiles_q(user_id, gender, gender_preference)
    |> where([p], p.user_id != ^user_id)
    |> where([p], p.last_active > ^treshold_date)
  end

  defp reported_user_ids_q(user_id) do
    UserReport |> where(from_user_id: ^user_id) |> select([r], r.on_user_id)
  end

  defp liked_user_ids_q(user_id) do
    Like |> where(by_user_id: ^user_id) |> select([l], l.user_id)
  end

  defp not_liked_profiles_q(query, user_id) do
    where(query, [p], p.user_id not in subquery(liked_user_ids_q(user_id)))
  end

  defp liker_user_ids_q(user_id) do
    Like |> where(user_id: ^user_id) |> select([l], l.by_user_id)
  end

  defp not_liker_profiles_q(query, user_id) do
    where(query, [p], p.user_id not in subquery(liker_user_ids_q(user_id)))
  end

  defp not_hidden_profiles_q do
    where(FeedProfile, hidden?: false)
  end

  defp not_reported_profiles_q(query \\ not_hidden_profiles_q(), user_id) do
    where(query, [p], p.user_id not in subquery(reported_user_ids_q(user_id)))
  end

  defp seen_user_ids_q(user_id) do
    SeenProfile |> where(by_user_id: ^user_id) |> select([s], s.user_id)
  end

  defp not_seen_profiles_q(query, user_id) do
    where(query, [p], p.user_id not in subquery(seen_user_ids_q(user_id)))
  end

  defp expired_match_user_ids_q(user_id) do
    ExpiredMatch |> where(user_id: ^user_id) |> select([s], s.with_user_id)
  end

  defp not_expired_match_with_q(query, user_id) do
    where(query, [p], p.user_id not in subquery(expired_match_user_ids_q(user_id)))
  end

  defp profiles_that_accept_gender_q(query, gender) do
    join(query, :inner, [p], gp in GenderPreference,
      on: gp.gender == ^gender and p.user_id == gp.user_id
    )
  end

  defp maybe_gender_preferenced_q(query, _no_preferences = []), do: query

  defp maybe_gender_preferenced_q(query, gender_preference) do
    where(query, [p], p.gender in ^gender_preference)
  end

  defp filtered_profiles_q(user_id, gender, gender_preference) when is_list(gender_preference) do
    not_hidden_profiles_q()
    |> not_reported_profiles_q(user_id)
    |> not_liked_profiles_q(user_id)
    |> not_liker_profiles_q(user_id)
    |> not_seen_profiles_q(user_id)
    |> not_expired_match_with_q(user_id)
    |> profiles_that_accept_gender_q(gender)
    |> maybe_gender_preferenced_q(gender_preference)
  end

  @doc "mark_profile_seen(user_id, by: <user-id>)"
  def mark_profile_seen(user_id, opts) do
    by_user_id = Keyword.fetch!(opts, :by)

    seen_changeset(by_user_id, user_id)
    |> Repo.insert()
    |> maybe_bump_shown_count(user_id)
  end

  defp seen_changeset(by_user_id, user_id) do
    %SeenProfile{by_user_id: by_user_id, user_id: user_id}
    |> change()
    |> unique_constraint(:seen, name: :seen_profiles_pkey)
  end

  defp maybe_bump_shown_count(repo, user_id) do
    case repo do
      {:ok, _} = result ->
        FeedProfile
        |> where(user_id: ^user_id)
        |> update(inc: [times_shown: 1])
        |> update(
          set: [like_ratio: fragment("times_liked::decimal / (times_shown::decimal + 1)")]
        )
        |> Repo.update_all([])

        result

      {:error, _} = error ->
        error
    end
  end

  def prune_seen_profiles(ttl_days) do
    SeenProfile
    |> where([s], s.inserted_at < fragment("now() - ? * interval '1 day'", ^ttl_days))
    |> Repo.delete_all()
  end
end
