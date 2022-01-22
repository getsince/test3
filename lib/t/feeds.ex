defmodule T.Feeds do
  @moduledoc "Feeds for alternative app. Invites & Calls."

  import Ecto.Query
  import Ecto.Changeset
  import Geo.PostGIS

  require Logger

  alias T.Repo
  alias T.Bot
  # alias T.Accounts
  alias T.Accounts.{Profile, UserReport, GenderPreference}
  alias T.Matches.{Match, Like, ExpiredMatch}
  alias T.Calls.Call
  alias T.Feeds.{FeedProfile, SeenProfile, FeededProfile, FeedFilter, LiveSession, LiveInvite}
  alias T.PushNotifications.DispatchJob

  ### PubSub

  # TODO optimise pubsub:
  # instead of single topic, use `up-to-filter` with each subscriber providing a value up to which
  # they are subscribed, and if the event is below that value -> send it, if not -> don't send it

  @pubsub T.PubSub
  @topic "__f"

  def subscribe_for_mode_change, do: subscribe(mode_change_topic())
  defp mode_change_topic, do: "__mode_change:"

  def subscribe_for_user(user_id) do
    Phoenix.PubSub.subscribe(@pubsub, pubsub_user_topic(user_id))
  end

  defp broadcast(topic, message) do
    Phoenix.PubSub.broadcast(@pubsub, topic, message)
  end

  defp pubsub_user_topic(user_id) when is_binary(user_id) do
    @topic <> ":u:" <> String.downcase(user_id)
  end

  def broadcast_for_user(user_id, message) do
    Phoenix.PubSub.broadcast(@pubsub, pubsub_user_topic(user_id), message)
  end

  defp subscribe(topic, opts \\ []) do
    Phoenix.PubSub.subscribe(@pubsub, topic, opts)
  end

  ### Live Feed

  @doc """
  This schedule defines start, end, and type of every Since Live event throughout a week.

  Oban crontabs are built based on what this function returns.
  """
  def live_schedule do
    [
      {_mon = 1, :newbie, [newbies_live_start_at(), newbies_live_end_at()]},
      {_tue = 2, :newbie, [newbies_live_start_at(), newbies_live_end_at()]},
      {_wed = 3, :newbie, [newbies_live_start_at(), newbies_live_end_at()]},
      {_thu = 4, :real, [_start = ~T[19:00:00], _end = ~T[21:00:00]]},
      {_fri = 5, :newbie, [newbies_live_start_at(), newbies_live_end_at()]},
      {_sat = 6, :real, [_start = ~T[20:00:00], _end = ~T[22:00:00]]},
      {_sun = 7, :newbie, [newbies_live_start_at(), newbies_live_end_at()]}
    ]
  end

  @doc """
  Finds out when the next real Since Live will happen:

      iex> mon_12_00 = DateTime.new!(~D[2021-12-20], ~T[12:00:00], "Europe/Moscow")
      iex> live_next_real_at(_now = mon_12_00)
      _thu_19_00_as_utc = ~U[2021-12-23 16:00:00Z]

      iex> thu_12_00 = DateTime.new!(~D[2021-12-23], ~T[12:00:00], "Europe/Moscow")
      iex> live_next_real_at(thu_12_00)
      _thu_19_00_as_utc = ~U[2021-12-23 16:00:00Z]

      # if today's event has started but hasn't yet ended, today's event is returned
      iex> thu_19_00 = DateTime.new!(~D[2021-12-23], ~T[19:00:00], "Europe/Moscow")
      iex> live_next_real_at(thu_19_00)
      _thu_19_00_as_utc = ~U[2021-12-23 16:00:00Z]

      iex> thu_21_00 = DateTime.new!(~D[2021-12-23], ~T[21:00:00], "Europe/Moscow")
      iex> live_next_real_at(thu_21_00)
      _thu_19_00_as_utc = ~U[2021-12-23 16:00:00Z]

      # if today's event has ended, next event is returned
      iex> thu_21_00_01 = DateTime.new!(~D[2021-12-23], ~T[21:00:01], "Europe/Moscow")
      iex> live_next_real_at(thu_21_00_01)
      _sat_20_00_as_utc = ~U[2021-12-25 17:00:00Z]

      # schedule wraps over to the next week
      iex> sun_12_00 = DateTime.new!(~D[2021-12-26], ~T[12:00:00], "Europe/Moscow")
      iex> live_next_real_at(sun_12_00)
      _thu_19_00_as_utc = ~U[2021-12-30 16:00:00Z]

  """
  def live_next_real_at(reference \\ DateTime.utc_now()) do
    msk_now = DateTime.shift_zone!(reference, "Europe/Moscow")
    weekday_today = Date.day_of_week(msk_now)

    [start_at, _end_at] =
      live_schedule()
      |> Enum.filter(fn {_weekday, type, _times} -> type == :real end)
      |> Enum.map(fn {weekday, _type, times} ->
        diff = weekday - weekday_today
        diff = if diff < 0, do: 7 + diff, else: diff

        Enum.map(times, fn time ->
          msk_now
          |> Date.add(diff)
          |> DateTime.new!(time, "Europe/Moscow")
        end)
      end)
      |> Enum.sort_by(fn [start_at, _end_at] -> start_at end, {:asc, Date})
      |> Enum.find(fn [_start_at, end_at] ->
        DateTime.compare(msk_now, end_at) in [:lt, :eq]
      end)

    DateTime.shift_zone!(start_at, "Etc/UTC")
  end

  @doc """
  Checks if there is an ongoing "Since Live" event and
  if it's "Since Live for newbies", checks if user_id is a newbie participant.

      # ongoing real Since Live
      iex> user_id = Ecto.Bigflake.UUID.generate()
      iex> thu_19_30 = DateTime.new!(~D[2021-12-23], ~T[19:30:00], "Europe/Moscow")
      iex> live_now?(user_id, thu_19_30)
      true

      # no ongoing Since Live
      iex> user_id = Ecto.Bigflake.UUID.generate()
      iex> thu_13_30 = DateTime.new!(~D[2021-12-23], ~T[13:30:00], "Europe/Moscow")
      iex> live_now?(user_id, thu_13_30)
      false

      # ongoing newbies Since Live, but user is not a participant
      iex> user_id = Ecto.Bigflake.UUID.generate()
      iex> mon_19_30 = DateTime.new!(~D[2021-12-20], ~T[19:30:00], "Europe/Moscow")
      iex> live_now?(user_id, mon_19_30, _newbies_live_enabled? = true)
      false

  """
  @spec live_now?(Ecto.UUID.t(), DateTime.t(), boolean()) :: boolean
  def live_now?(user_id, reference \\ DateTime.utc_now(), newbies_live_enabled? \\ false) do
    msk_now = DateTime.shift_zone!(reference, "Europe/Moscow")
    weekday_today = Date.day_of_week(msk_now)

    {_weekday, type, [start_at, end_at]} =
      Enum.find(live_schedule(), fn {weekday, _type, _times} -> weekday == weekday_today end)

    ongoing? =
      Time.compare(start_at, msk_now) in [:eq, :lt] and
        Time.compare(end_at, msk_now) in [:eq, :gt]

    if ongoing? do
      case type do
        :newbie ->
          if newbies_live_enabled? do
            is_a_newbies_participant?(user_id, reference)
          end

        :real ->
          true
      end
    end || false
  end

  @doc """
  Returns type and starting and ending datetimes for today's Since Live event.

      iex> mon_12_00 = DateTime.new!(~D[2021-12-20], ~T[12:00:00], "Europe/Moscow")
      iex> live_today(_now = mon_12_00)
      {:newbie, [~U[2021-12-20 16:00:00Z], ~U[2021-12-20 17:00:00Z]]}

      iex> thu_12_00 = DateTime.new!(~D[2021-12-23], ~T[12:00:00], "Europe/Moscow")
      iex> live_today(_now = thu_12_00)
      {:real, [~U[2021-12-23 16:00:00Z], ~U[2021-12-23 18:00:00Z]]}

      iex> sat_12_00 = DateTime.new!(~D[2021-12-25], ~T[12:00:00], "Europe/Moscow")
      iex> live_today(_now = sat_12_00)
      {:real, [~U[2021-12-25 17:00:00Z], ~U[2021-12-25 19:00:00Z]]}

      # note that past events for today might be returned
      iex> sat_23_00 = DateTime.new!(~D[2021-12-25], ~T[23:00:00], "Europe/Moscow")
      iex> live_today(_now = sat_23_00)
      {:real, [~U[2021-12-25 17:00:00Z], ~U[2021-12-25 19:00:00Z]]}

  """
  @spec live_today(DateTime.t() | Date.t()) :: {:real | :newbie, [DateTime.t()]}
  def live_today(reference \\ DateTime.utc_now())

  def live_today(%DateTime{} = reference) do
    msk_now = DateTime.shift_zone!(reference, "Europe/Moscow")
    msk_today = DateTime.to_date(msk_now)
    live_today(msk_today)
  end

  def live_today(%Date{} = today) do
    weekday_today = Date.day_of_week(today)

    {_weekday, type, times} =
      Enum.find(live_schedule(), fn {weekday, _type, _times} -> weekday == weekday_today end)

    times =
      Enum.map(times, fn time ->
        today
        |> DateTime.new!(time, "Europe/Moscow")
        |> DateTime.shift_zone!("Etc/UTC")
      end)

    {type, times}
  end

  @doc """
  Generates "Since Live" `:crontab` for Oban's `Oban.Plugins.Cron`:

      iex> live_crontab()
      [
        # https://crontab.guru/#0_13_*_*_4
        {"00 13 * * 4", T.PushNotifications.DispatchJob, args: %{"type" => "live_mode_today", "time" => "19:00"}},
        {"45 18 * * 4", T.PushNotifications.DispatchJob, args: %{"type" => "live_mode_soon"}},
        {"00 19 * * 4", T.Feeds.Live.StartJob},
        {"00 21 * * 4", T.Feeds.Live.EndJob},
        {"00 14 * * 6", T.PushNotifications.DispatchJob, args: %{"type" => "live_mode_today", "time" => "20:00"}},
        {"45 19 * * 6", T.PushNotifications.DispatchJob, args: %{"type" => "live_mode_soon"}},
        {"00 20 * * 6", T.Feeds.Live.StartJob},
        {"00 22 * * 6", T.Feeds.Live.EndJob}
      ]

  """
  def live_crontab do
    live_schedule()
    |> Enum.filter(fn {_weekday, type, _times} -> type == :real end)
    |> Enum.group_by(
      fn {_weekday, _type, times} -> times end,
      fn {weekday, _type, _times} -> weekday end
    )
    |> Enum.flat_map(fn {[start_at, end_at], weekdays} ->
      alias T.Feeds.Live.{StartJob, EndJob}

      today_notification_at = Time.add(start_at, _six_hours = -6 * 3600)
      soon_notification_at = Time.add(start_at, _15_minutes = -15 * 60)
      cron_days = cron_days(weekdays)

      [
        {cron_rule(today_notification_at, cron_days), DispatchJob,
         args: %{"type" => "live_mode_today", "time" => Calendar.strftime(start_at, "%H:%M")}},
        {cron_rule(soon_notification_at, cron_days), DispatchJob,
         args: %{"type" => "live_mode_soon"}},
        {cron_rule(start_at, cron_days), StartJob},
        {cron_rule(end_at, cron_days), EndJob}
      ]
    end)
  end

  @spec cron_rule(Time.t(), String.t()) :: String.t()
  defp cron_rule(time, cron_days) when is_binary(cron_days) do
    cron_time(time) <> " * * " <> cron_days
  end

  @spec cron_days([pos_integer]) :: String.t()
  defp cron_days(weekdays) do
    # cron days of week start at 0 (Sunday), elixir days of week start at 1 (Monday)
    weekdays |> Enum.map(fn weekday -> rem(weekday, 7) end) |> Enum.join(",")
  end

  @spec cron_time(Time.t()) :: String.t()
  defp cron_time(time) do
    Calendar.strftime(time, "%M %H")
  end

  defp broadcast_mode_change_start(topic \\ mode_change_topic()) do
    broadcast(topic, {__MODULE__, [:mode_change, :start]})
  end

  defp broadcast_mode_change_end do
    broadcast(mode_change_topic(), {__MODULE__, [:mode_change, :end]})
  end

  @doc """
  Starts a "Since Live" event:

    - sends a message to the admin tg bot
    - broadcasts a push notification to all users
    - broadcasts a `:start` event to all `:mode_change` subscribers (feed channels)

  This function shouldn't be called directly, but rather scheduled with Oban in crontab.
  """
  def live_mode_start do
    m = "LIVE started"
    Logger.warn(m)
    Bot.async_post_message(m)

    broadcast_mode_change_start()

    T.Accounts.list_apns_devices()
    |> DispatchJob.schedule_apns("live_mode_started", _data = %{})

    :ok
  end

  @doc """
  Ends a "Since Live" event:

    - broadcasts an `:end` event to all `:mode_change` subscribers (feed channels)
    - broadcasts a push notification to all users with the next date
    - clears live tables

  This function shouldn't be called directly, but rather scheduled with Oban in crontab.
  """
  @spec live_mode_end(DateTime.t()) :: :ok
  def live_mode_end(reference \\ DateTime.utc_now()) do
    broadcast_mode_change_end()

    next_live_event_on =
      reference
      |> live_next_real_at()
      |> DateTime.shift_zone!("Europe/Moscow")
      |> DateTime.to_date()

    T.Accounts.list_apns_devices()
    |> DispatchJob.schedule_apns(
      "live_mode_ended",
      _data = %{"next" => next_live_event_on}
    )

    {_type, [started_at, _ended_at]} = live_today(reference)
    clear_live_tables(started_at)

    :ok
  end

  defp clear_live_tables(session_start_time) do
    {invites_count, _} = Repo.delete_all(LiveInvite)
    {sessions_count, _} = Repo.delete_all(LiveSession)

    calls_count =
      Call
      |> where([c], c.accepted_at > ^session_start_time)
      |> select([c], count())
      |> Repo.one!()

    m =
      "LIVE ended, there were #{sessions_count} users with #{invites_count} invites and #{calls_count} successful calls"

    Logger.warn(m)
    Bot.async_post_message(m)

    :ok
  end

  # TODO test pubsub
  @spec maybe_activate_session(Ecto.UUID.t(), String.t(), %FeedFilter{}) :: %LiveSession{}
  def maybe_activate_session(user_id, gender, feed_filter) do
    is_already_live? = LiveSession |> where(user_id: ^user_id) |> Repo.exists?()

    unless is_already_live? do
      profile = FeedProfile |> where(user_id: ^user_id) |> Repo.one!()
      m = "user #{profile.name} (#{user_id}) activated LIVE session"
      Logger.warn(m)
      Bot.async_post_message(m)

      live_session =
        Repo.insert!(%LiveSession{user_id: user_id},
          on_conflict: :replace_all,
          conflict_target: :user_id
        )

      unless profile.hidden? do
        blockers =
          T.Accounts.UserReport
          |> where([r], r.on_user_id == ^user_id or r.from_user_id == ^user_id)
          |> select([r], [r.on_user_id, r.from_user_id])
          |> Repo.all()
          |> Enum.map(fn users -> users -- [user_id] end)

        matches =
          Match
          |> where([m], m.user_id_1 == ^user_id or m.user_id_2 == ^user_id)
          |> select([m], {[m.user_id_1, m.user_id_2], m.id})
          |> Repo.all()
          |> Enum.map(fn {mates, match_id} ->
            [mate_id] = mates -- [user_id]
            {mate_id, match_id}
          end)

        matches
        |> Enum.map(fn {mate_id, _match_id} ->
          DispatchJob.new(%{
            "type" => "match_went_live",
            "user_id" => user_id,
            "for_user_id" => mate_id
          })
        end)
        |> Oban.insert_all()

        broadcast_new_live_session(
          profile,
          gender,
          feed_filter.genders,
          blockers,
          Map.new(matches)
        )
      end

      live_session
    end
  end

  @live_topic "__live"

  defp live_session_metadata(user_id, gender, want_genders) do
    %{user_id: user_id, gender: gender, want_genders: want_genders}
  end

  def subscribe_for_live_sessions(user_id, gender, want_genders) when is_list(want_genders) do
    metadata = live_session_metadata(user_id, gender, want_genders)
    subscribe(@live_topic, metadata: metadata)
  end

  # TODO use pubsub dispatcher
  defp broadcast_new_live_session(profile, my_gender, my_want_genders, blockers, matches) do
    me = profile.user_id
    payload = %{profile: profile}
    live_payload = {__MODULE__, :live, payload}
    subscribers = Registry.lookup(@pubsub, @live_topic)

    Enum.each(subscribers, fn {pid, metadata} ->
      %{user_id: user_id, gender: their_gender, want_genders: they_want_genders} = metadata

      cond do
        user_id == me ->
          :ignore

        user_id in blockers ->
          :ignore

        match_id = matches[user_id] ->
          send(pid, {__MODULE__, :live_match_online, Map.put(payload, :match_id, match_id)})

        my_gender in they_want_genders and their_gender in my_want_genders ->
          send(pid, live_payload)

        true ->
          :ignore
      end
    end)
  end

  @type feed_cursor :: String.t()

  @spec fetch_live_feed(
          Ecto.UUID.t(),
          String.t(),
          %FeedFilter{},
          pos_integer,
          feed_cursor | nil
        ) ::
          {[%FeedProfile{}], feed_cursor}
  def fetch_live_feed(user_id, gender, feed_filter, count, feed_cursor) do
    %FeedFilter{
      genders: gender_preferences
    } = feed_filter

    profiles_q =
      user_id
      |> filtered_live_profiles_q()
      |> profiles_that_accept_gender_q(gender)
      |> maybe_gender_preferenced_q(gender_preferences)

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
    # TODO refactor
    reported? =
      UserReport
      |> where(from_user_id: ^user_id)
      |> where(on_user_id: ^by_user_id)
      |> Repo.exists?()

    hidden? = FeedProfile |> where(user_id: ^by_user_id) |> select([p], p.hidden?) |> Repo.one!()

    case {reported?, hidden?} do
      {false, false} ->
        name_by_user_id =
          Profile |> where(user_id: ^by_user_id) |> select([p], p.name) |> Repo.one!()

        name_user_id = Profile |> where(user_id: ^user_id) |> select([p], p.name) |> Repo.one!()

        m = "#{name_by_user_id} (#{by_user_id}) LIVE invited #{name_user_id} (#{user_id})"
        Logger.warn(m)
        Bot.async_post_message(m)

        %LiveInvite{by_user_id: by_user_id, user_id: user_id}
        |> Repo.insert!(on_conflict: :replace_all, conflict_target: [:by_user_id, :user_id])

        notify_invited_user(by_user_id, user_id)

      _ ->
        nil
    end
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

  # newbies and stuff

  @doc """
  Generates "Since Live for newbies" `:crontab` for Oban's `Oban.Plugins.Cron`:

      iex> newbies_crontab()
      [
        # https://crontab.guru/#0_13_*_*_1,2,3,5,0
        {"00 13 * * 1,2,3,5,0", T.PushNotifications.DispatchJob, args: %{"type" => "newbie_live_mode_today", "time" => "19:00"}},
        {"45 18 * * 1,2,3,5,0", T.PushNotifications.DispatchJob, args: %{"type" => "newbie_live_mode_soon"}},
        {"00 19 * * 1,2,3,5,0", T.Feeds.NewbiesLive.StartJob},
        {"00 20 * * 1,2,3,5,0", T.Feeds.NewbiesLive.EndJob}
      ]

  """
  def newbies_crontab do
    live_schedule()
    |> Enum.filter(fn {_weekday, type, _times} -> type == :newbie end)
    |> Enum.group_by(
      fn {_weekday, _type, times} -> times end,
      fn {weekday, _type, _times} -> weekday end
    )
    |> Enum.flat_map(fn {[start_at, end_at], weekdays} ->
      alias T.Feeds.NewbiesLive.{StartJob, EndJob}

      today_notification_at = Time.add(start_at, _six_hours = -6 * 3600)
      soon_notification_at = Time.add(start_at, _15_minutes = -15 * 60)
      cron_days = cron_days(weekdays)

      [
        {cron_rule(today_notification_at, cron_days), DispatchJob,
         args: %{
           "type" => "newbie_live_mode_today",
           "time" => Calendar.strftime(start_at, "%H:%M")
         }},
        {cron_rule(soon_notification_at, cron_days), DispatchJob,
         args: %{"type" => "newbie_live_mode_soon"}},
        {cron_rule(start_at, cron_days), StartJob},
        {cron_rule(end_at, cron_days), EndJob}
      ]
    end)
  end

  @doc """
  Starts a "Since Live" event for newbies:

    - sends a message to the admin tg bot
    - broadcasts a push notification to all participants
    - broadcasts a `:start` event to all newbies' feed channels

  This function shouldn't be called directly, but rather scheduled with Oban in crontab.
  """
  @spec newbies_start_live(DateTime.t()) :: :ok
  def newbies_start_live(reference \\ DateTime.utc_now()) do
    newbies = newbies_list_today_participants(reference)

    m = "LIVE (newbie's special edition) started: newbies count #{length(newbies)}"
    Logger.warn(m)
    Bot.async_post_message(m)

    Enum.each(newbies, fn user_id ->
      feed_channel_topic = "feed:" <> user_id
      broadcast_mode_change_start(feed_channel_topic)
    end)

    newbies
    |> T.Accounts.list_apns_devices()
    |> DispatchJob.schedule_apns("newbie_live_mode_started", _data = %{})

    :ok
  end

  @doc """
  Ends a "Since Live" event for newbies:

    - sends a message to the admin tg bot
    - broadcasts an `:end` event to all `:mode_change` subscribers
    - broadcasts a push notification to all participants with the next "real live" date
    - clears live tables

  This function shouldn't be called directly, but rather scheduled with Oban in crontab.
  """
  @spec newbies_end_live(DateTime.t()) :: :ok
  def newbies_end_live(reference \\ DateTime.utc_now()) do
    newbies = newbies_list_today_participants(reference)

    m = "LIVE (newbie's special edition) ended"
    Logger.warn(m)
    Bot.async_post_message(m)

    # we don't need to send `end` event only to newbies,
    # we can turn off everyone who's live right now
    # since "newbie live" and "normal live" don't intersect
    broadcast_mode_change_end()

    next_live_event_on =
      reference
      |> live_next_real_at()
      |> DateTime.shift_zone!("Europe/Moscow")
      |> DateTime.to_date()

    newbies
    |> T.Accounts.list_apns_devices()
    |> DispatchJob.schedule_apns(
      "newbie_live_mode_ended",
      _data = %{"next" => next_live_event_on}
    )

    {_type, [started_at, _ended_at]} = live_today(reference)
    clear_live_tables(started_at)

    :ok
  end

  @doc """
  Lists ids of today's "newbies live" participants.

  "newbies live" participants are:
  - newbies: users who have registered since the last newbies live
  - oldies or "midwives": experienced users who explain newbies what all this is about

  """
  @spec newbies_list_today_participants(DateTime.t()) :: [Ecto.UUID.t()]
  def newbies_list_today_participants(reference \\ DateTime.utc_now()) do
    # maybe Repo.stream later
    newbies = Repo.all(newbies_q(reference))
    hardcoded_oldies() ++ newbies
  end

  defp hardcoded_oldies do
    Application.get_env(:t, :oldies) || []
  end

  # TODO move to accounts.ex? maybe later
  @spec newbies_q(DateTime.t()) :: Ecto.Query.t()
  defp newbies_q(reference) do
    _yesterday_event =
      {_type, [_started_at, live_ended_at]} =
      reference |> DateTime.shift_zone!("Europe/Moscow") |> Date.add(-1) |> live_today()

    T.Accounts.User
    |> where([u], is_nil(u.blocked_at))
    |> where([u], not is_nil(u.onboarded_at))
    |> where([u], not is_nil(u.onboarded_with_story_at))
    |> where([u], u.onboarded_with_story_at > ^live_ended_at)
    |> join(:inner, [u], p in FeedProfile, on: u.id == p.user_id and not p.hidden?)
    |> select([u], u.id)
  end

  @spec is_a_newbies_participant?(Ecto.UUID.t(), DateTime.t()) :: boolean
  defp is_a_newbies_participant?(user_id, reference) do
    user_id in hardcoded_oldies() or is_newbie?(user_id, reference)
  end

  @spec is_newbie?(Ecto.UUID.t(), DateTime.t()) :: boolean
  defp is_newbie?(user_id, reference) do
    newbies_q(reference)
    |> where(id: ^user_id)
    |> Repo.exists?()
  end

  defp newbies_live_start_at, do: ~T[19:00:00]
  defp newbies_live_end_at, do: ~T[20:00:00]
end
