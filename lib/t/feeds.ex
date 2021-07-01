defmodule T.Feeds do
  @moduledoc "Feeds and liking feeds"
  import Ecto.{Query, Changeset}

  alias T.{Repo, Matches, Accounts}
  alias T.Accounts.{Profile, UserReport, GenderPreference}
  alias T.PushNotifications.DispatchJob
  alias T.Feeds.{Feeded, SeenProfile, ProfileLike, LikeJob}

  @pubsub T.PubSub
  @topic to_string(__MODULE__)

  defp pubsub_likes_topic(user_id) when is_binary(user_id) do
    @topic <> ":l:" <> String.downcase(user_id)
  end

  def subscribe_for_likes(user_id) do
    Phoenix.PubSub.subscribe(@pubsub, pubsub_likes_topic(user_id))
  end

  defp notify_subscribers(
         {:ok, %{like: %ProfileLike{user_id: to} = like}} = success,
         :liked = event
       ) do
    msg = {__MODULE__, event, like}
    Phoenix.PubSub.broadcast(@pubsub, pubsub_likes_topic(to), msg)
    success
  end

  defp notify_subscribers({:error, _field, _reason, _changes} = error, _event) do
    error
  end

  defp notify_subscribers({:error, _reason} = error, _event) do
    error
  end

  ######################### LIKE #########################

  # TODO auth, check user_id in by_user_id feed
  @doc false
  def like_profile(by_user_id, user_id) do
    Ecto.Multi.new()
    |> mark_profile_seen(by_user_id, user_id)
    |> mark_liked(by_user_id, user_id)
    |> bump_likes_count(user_id)
    |> Matches.match_if_mutual_m(by_user_id, user_id)
    |> maybe_schedule_like_push_notification()
    |> Repo.transaction()
    |> Matches.maybe_notify_of_match()
    |> notify_subscribers(:liked)
  end

  # TODO test
  def schedule_like_profile(by_user_id, user_id, schedule_in_seconds \\ 10) do
    args = %{"by_user_id" => by_user_id, "user_id" => user_id}
    job = LikeJob.new(args, schedule_in: schedule_in_seconds)
    Oban.insert(job)
  end

  defp list_like_jobs(by_user_id, user_id) do
    Oban.Job
    |> where(worker: ^dump_worker_to_string(LikeJob))
    |> where([j], j.state not in ["completed", "discarded", "cancelled"])
    |> where([j], j.args["by_user_id"] == ^by_user_id and j.args["user_id"] == ^user_id)
    |> Repo.all()
  end

  defp dump_worker_to_string(worker) do
    worker |> to_string() |> String.replace_leading("Elixir.", "")
  end

  # TODO test
  def cancel_like_profile(by_user_id, user_id) do
    jobs = list_like_jobs(by_user_id, user_id)
    cancelled_jobs = Enum.map(jobs, fn job -> Oban.cancel_job(job.id) end)
    not Enum.empty?(cancelled_jobs)
  end

  # TODO broadcast
  def dislike_liker(liker_id, opts) do
    by_user_id = Keyword.fetch!(opts, :by)

    {count, _other} =
      ProfileLike
      |> where(by_user_id: ^liker_id)
      |> where(user_id: ^by_user_id)
      |> Repo.delete_all()

    count == 1
  end

  # TODO broadcast
  @doc "mark_profile_seen(user_id, by: <user-id>)"
  def mark_profile_seen(user_id, opts) do
    by_user_id = Keyword.fetch!(opts, :by)

    seen_changeset(by_user_id, user_id)
    |> Repo.insert()
  end

  defp mark_profile_seen(multi, by_user_id, user_id) do
    Ecto.Multi.insert(multi, :seen, seen_changeset(by_user_id, user_id), on_conflict: :nothing)
  end

  defp seen_changeset(by_user_id, user_id) do
    %SeenProfile{by_user_id: by_user_id, user_id: user_id}
    |> change()
    |> unique_constraint(:seen, name: :seen_profiles_pkey)
  end

  defp mark_liked(multi, by_user_id, user_id) do
    changeset =
      %ProfileLike{by_user_id: by_user_id, user_id: user_id}
      |> change()
      |> unique_constraint(:like, name: :liked_profiles_pkey)

    Ecto.Multi.insert(multi, :like, changeset)
  end

  defp maybe_schedule_like_push_notification(multi) do
    Ecto.Multi.run(multi, :push_notification, fn _repo, %{like: like, match: match} ->
      if match do
        {:ok, nil}
      else
        %ProfileLike{by_user_id: by_user_id, user_id: user_id} = like

        job =
          DispatchJob.new(%{"type" => "like", "by_user_id" => by_user_id, "user_id" => user_id})

        Oban.insert(job)
      end
    end)
  end

  defp bump_likes_count(multi, user_id) do
    Ecto.Multi.run(multi, :bump_likes, fn _repo, _changes ->
      {1, [count]} =
        Profile
        |> where(user_id: ^user_id)
        |> select([p], p.times_liked)
        |> Repo.update_all(inc: [times_liked: 1])

      {:ok, count}
    end)
  end

  def all_profile_likes_with_liker_profile(user_id) do
    matches =
      Matches.Match
      |> where([m], m.user_id_1 == ^user_id or m.user_id_2 == ^user_id)

    ProfileLike
    |> where(user_id: ^user_id)
    |> join(:inner, [l], p in Profile, on: p.user_id == l.by_user_id)
    |> join(:left, [l, p], m in subquery(matches),
      on: p.user_id == m.user_id_1 or p.user_id == m.user_id_2
    )
    |> where([l, p, m], is_nil(m.id))
    |> select([l, p], %ProfileLike{l | liker_profile: p, seen?: coalesce(l.seen?, false)})
    |> order_by([l, p], desc: l.inserted_at)
    |> Repo.all()
  end

  def preload_liker_profile(%ProfileLike{liker_profile: %Profile{}} = like), do: like

  def preload_liker_profile(%ProfileLike{by_user_id: by_user_id, liker_profile: nil} = like) do
    %ProfileLike{like | liker_profile: Accounts.get_profile!(by_user_id)}
  end

  @doc "mark_liker_seen(<user-id>, by: <user-id>)"
  def mark_liker_seen(user_id, opts) do
    liked_id = Keyword.fetch!(opts, :by)

    {count, _} =
      ProfileLike
      |> where(user_id: ^liked_id)
      |> where(by_user_id: ^user_id)
      |> Repo.update_all(set: [seen?: true])

    count == 1
  end

  ######################### FEED #########################

  @spec onboarding_feed :: [%Profile{}]
  def onboarding_feed do
    user_ids = [
      "0000017a-2ed5-a8b1-0242-ac1100030000",
      "0000017a-2f3f-45d9-0242-ac1100030000",
      "0000017a-2e20-ef74-0242-ac1100030000",
      "0000017a-2dda-4b8b-0242-ac1100030000",
      "00000177-868a-728a-0242-ac1100030000"
    ]

    ordered_profiles(user_ids)
  end

  # todo remove
  @spec yabloko_feed :: [%Profile{}]
  def yabloko_feed do
    # My,
    # 02
    # 03
    # 04
    # Vlad
    # Mura
    # Alex
    # Nikita

    user_ids = [
      "0000017a-2dda-4b8b-0242-ac1100030000",
      "00000177-868a-728a-0242-ac1100030000",
      "0000017a-2ed5-a8b1-0242-ac1100030000",
      "0000017a-2f3f-45d9-0242-ac1100030000",
      "0000017a-20b3-852f-0242-ac1100030000",
      "0000017a-422a-563e-0242-ac1100030000",
      "0000017a-4df8-6f52-0242-ac1100030000",
      "0000017a-483e-7c55-0242-ac1100030000"
    ]

    ordered_profiles(user_ids)
  end

  defp ordered_profiles(user_ids) do
    profiles =
      Profile
      |> where([p], p.user_id in ^user_ids)
      |> Repo.all()
      |> Map.new(fn profile -> {profile.user_id, profile} end)

    user_ids
    |> Enum.map(fn user_id -> profiles[user_id] end)
    |> Enum.reject(&is_nil/1)
  end

  @spec init_batched_feed(%Profile{}, Keyword.t()) :: %{
          loaded: [%Profile{}],
          next_ids: [Ecto.UUID.t()]
        }
  @doc "init_batched_feed(profile, loaded: 13)"
  def init_batched_feed(%Profile{user_id: user_id} = profile, opts \\ []) do
    cached_feed_f = fn ->
      Sentry.Context.set_user_context(%{id: user_id})
      get_cached_feed_or_nil(user_id) || push_more_to_cached_feed(profile, 100)
    end

    {:ok, user_ids} = Repo.transaction(cached_feed_f)

    case user_ids do
      [] -> %{loaded: [], next_ids: []}
      _not_empty -> continue_batched_feed(user_ids, profile, opts)
    end
  end

  @doc """
  Continues fetching from next_ids returned from `init_batched_feed/2`.

  After each fetch, it asynchronously pushes more profiles to cached feed.
  After each fetch, it asynchronously removes loaded ids from cached feed.
  """
  @spec continue_batched_feed([Ecto.UUID.t()], %Profile{}, Keyword.t()) :: %{
          loaded: [%Profile{}],
          next_ids: [Ecto.UUID.t()]
        }
  def continue_batched_feed(next_ids, profile, opts \\ [])

  def continue_batched_feed([], profile, opts) do
    init_batched_feed(profile, opts)
  end

  def continue_batched_feed(next_ids, %Profile{user_id: user_id} = profile, opts)
      when is_list(next_ids) do
    loaded_count = opts[:loaded] || 10
    {to_fetch, next_ids} = Enum.split(next_ids, loaded_count)

    next_ids_len = length(next_ids)

    if next_ids_len < 30 do
      async_push_more_to_cached_feed(profile, 100 - next_ids_len)
    end

    loaded =
      Profile
      |> where(hidden?: false)
      |> where([p], p.user_id in ^to_fetch)
      |> Repo.all()

    case {loaded, next_ids} do
      {[], []} ->
        remove_loaded_from_cached_feed(user_id, to_fetch)
        continue_batched_feed([], profile, opts)

      # TODO
      {loaded1, [] = next_ids} ->
        remove_loaded_from_cached_feed(user_id, to_fetch)
        # %{loaded: loaded2, next_ids: next_ids} = continue_batched_feed([], profile, opts)
        %{loaded: loaded1, next_ids: next_ids}

      {[], next_ids} ->
        async_remove_loaded_from_cached_feed(user_id, to_fetch)
        continue_batched_feed(next_ids, profile, opts)

      {loaded, next_ids} ->
        async_remove_loaded_from_cached_feed(user_id, to_fetch)
        %{loaded: loaded, next_ids: next_ids}
    end
  end

  @spec get_cached_feed_or_nil(Ecto.UUID.t()) :: [Ecto.UUID.t()] | nil
  defp get_cached_feed_or_nil(user_id) do
    Feeded
    |> where(user_id: ^user_id)
    |> select([f], f.feeded_id)
    |> Repo.all()
    |> case do
      [] -> nil
      not_empty -> not_empty
    end
  end

  defp async_remove_loaded_from_cached_feed(user_id, to_remove_ids) do
    Task.start(fn -> remove_loaded_from_cached_feed(user_id, to_remove_ids) end)
  end

  defp remove_loaded_from_cached_feed(user_id, to_remove_ids) do
    Feeded
    |> where(user_id: ^user_id)
    |> where([f], f.feeded_id in ^to_remove_ids)
    |> Repo.delete_all()
  end

  defp async_push_more_to_cached_feed(profile, count) do
    Task.start(fn -> push_more_to_cached_feed(profile, count) end)
  end

  defp seen_user_ids_q(user_id) do
    SeenProfile |> where(by_user_id: ^user_id) |> select([s], s.user_id)
  end

  defp reported_user_ids_q(user_id) do
    UserReport |> where(from_user_id: ^user_id) |> select([r], r.on_user_id)
  end

  defp interested_in_gender_q(gender) when gender in ["M", "F", "N"] do
    # TODO is distinct ok for performance?
    GenderPreference |> where(gender: ^gender) |> distinct(true) |> select([g], g.user_id)
  end

  defp matches_ids_q(user_id) do
    q1 = Matches.Match |> where([m], m.user_id_1 == ^user_id) |> select([m], m.user_id_2)
    q2 = Matches.Match |> where([m], m.user_id_2 == ^user_id) |> select([m], m.user_id_1)
    union(q1, ^q2)
  end

  defp liked_user_ids_q(user_id) do
    ProfileLike |> where(by_user_id: ^user_id) |> select([l], l.user_id)
  end

  @doc false
  def push_more_to_cached_feed(%Profile{user_id: user_id, gender: gender} = profile, count) do
    Sentry.Context.set_user_context(%{user_id: user_id})
    seen_user_ids = seen_user_ids_q(user_id)
    liked_user_ids = liked_user_ids_q(user_id)
    reported_user_ids = reported_user_ids_q(user_id)
    # TODO
    interested_in_us = interested_in_gender_q(gender)
    matches_ids = matches_ids_q(user_id)

    likers_count = floor(count / 2)
    not_liked_count = ceil(count / 2)

    # TODO take location into account
    common_q =
      Profile
      # TODO is performance ok?
      |> join(:inner, [p], i in subquery(interested_in_us), on: i.user_id == p.user_id)
      |> where([p], p.user_id != ^user_id)
      |> where(hidden?: false)
      |> where([p], p.gender in ^preferred_genders(profile))
      |> where([p], p.user_id not in subquery(seen_user_ids))
      |> where([p], p.user_id not in subquery(reported_user_ids))
      |> where([p], p.user_id not in subquery(matches_ids))
      |> where([p], p.user_id not in subquery(liked_user_ids))
      |> select([p], p.user_id)

    most_liked_user_ids =
      common_q
      |> order_by([p], desc: p.times_liked)
      |> limit(^likers_count)
      |> Repo.all()

    not_liked_user_ids =
      common_q
      |> where([p], p.user_id not in ^most_liked_user_ids)
      |> where(times_liked: 0)
      # TODO add this clause if it doesn't slow down the query
      # |> order_by([p], desc: p.user_id)
      |> limit(^not_liked_count)
      |> Repo.all()

    user_ids = Enum.shuffle(most_liked_user_ids ++ not_liked_user_ids)
    to_insert = Enum.map(user_ids, &%{feeded_id: &1, user_id: user_id})
    Repo.insert_all(Feeded, to_insert, on_conflict: :nothing)
    user_ids
  end

  defp preferred_genders(%Profile{filters: %Profile.Filters{genders: genders}})
       when is_list(genders),
       do: genders

  defp preferred_genders(%Profile{gender: "F"}), do: ["M"]
  defp preferred_genders(%Profile{gender: "M"}), do: ["F"]

  def prune_seen_profiles(ttl_days) do
    SeenProfile
    |> where([s], s.inserted_at < fragment("now() - ? * interval '1 day'", ^ttl_days))
    |> Repo.delete_all()
  end
end
