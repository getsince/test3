defmodule T.Feeds do
  @moduledoc "Feeds and liking feeds"
  import Ecto.{Query, Changeset}

  alias T.{Repo, Matches, Accounts}
  alias T.Accounts.Profile
  alias T.PushNotifications.DispatchJob
  alias T.Feeds.{Feed, SeenProfile, ProfileLike, PersonalityOverlap, LikeJob}

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
    # |> mark_seen(by_user_id, user_id)
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

  defp get_like_job(by_user_id, user_id) do
    Oban.Job
    |> where(worker: ^dump_worker_to_string(LikeJob))
    |> where([j], j.args["by_user_id"] == ^by_user_id and j.args["user_id"] == ^user_id)
    |> Repo.one()
  end

  defp dump_worker_to_string(worker) do
    worker |> to_string() |> String.replace_leading("Elixir.", "")
  end

  # TODO test
  def cancel_like_profile(by_user_id, user_id) do
    cancelled? = if job = get_like_job(by_user_id, user_id), do: Oban.cancel_job(job.id)
    !!cancelled?
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

    %SeenProfile{by_user_id: by_user_id, user_id: user_id}
    |> change()
    |> unique_constraint(:seen, name: :seen_profiles_pkey)
    |> Repo.insert()
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

  # TODO remove after nobody is using like_channel version 1
  def all_likers(user_id) do
    likers =
      ProfileLike
      |> where(user_id: ^user_id)

    matches =
      Matches.Match
      |> where(alive?: true)
      |> where([m], m.user_id_1 == ^user_id or m.user_id_2 == ^user_id)

    Profile
    |> join(:inner, [p], l in subquery(likers), on: p.user_id == l.by_user_id)
    |> join(:left, [p, l], m in subquery(matches),
      on: p.user_id == m.user_id_1 or p.user_id == m.user_id_2
    )
    |> where([p, l, m], is_nil(m.id))
    |> select([p, l], %Profile{p | seen?: coalesce(l.seen?, false)})
    # TODO index
    |> order_by([p, l], desc: l.inserted_at)
    |> Repo.all()
  end

  # this one is used in like_channel version 2 and above
  def all_profile_likes_with_liker_profile(user_id) do
    matches =
      Matches.Match
      |> where(alive?: true)
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

  def get_or_create_feed(%Profile{} = profile, date \\ Date.utc_today(), opts \\ []) do
    f = fn -> get_feed(profile, date, opts) || create_feed(profile, date) end
    {:ok, profiles} = Repo.transaction(f)
    Enum.shuffle(profiles)
  end

  def use_demo_feed(use?) when is_boolean(use?) do
    Application.put_env(:t, :use_demo_feed?, use?)
  end

  def use_demo_feed? do
    !!Application.get_env(:t, :use_demo_feed?)
  end

  @doc "demo_feed(profile, count: 13)"
  def demo_feed(profile, opts \\ []) do
    # user_ids = [
    #   "00000177-679a-ad79-0242-ac1100030000",
    #   "00000177-8ae4-b4c4-0242-ac1100030000",
    #   "00000177-830a-a7d0-0242-ac1100030000",
    #   "00000177-82ed-c4c9-0242-ac1100030000",
    #   "00000177-809e-4ef7-0242-ac1100030000",
    #   "00000177-7d1f-61be-0242-ac1100030000"
    # ]

    first_real = "00000177-679a-ad79-0242-ac1100030000"
    kj = "00000177-8336-5e0e-0242-ac1100030000"

    already_liked = ProfileLike |> where(by_user_id: ^profile.user_id) |> select([s], s.user_id)

    real =
      Profile
      |> where([p], p.user_id != ^profile.user_id)
      |> where([p], p.user_id != ^kj)
      |> where([p], p.user_id >= ^first_real)
      |> where([p], p.user_id not in subquery(already_liked))
      |> where([p], not p.hidden?)
      |> Repo.all()
      |> Enum.shuffle()

    fakes =
      Profile
      |> where([p], p.user_id < ^first_real)
      |> where([p], p.user_id not in subquery(already_liked))
      |> where([p], p.gender == "F")
      |> maybe_limit(opts[:fakes_count])

      # |> order_by([p], desc: p.user_id)
      |> Repo.all()
      |> Enum.shuffle()

    real ++ fakes
  end

  @doc "batched_demo_feed(profile or user_id, loaded: 13)"
  def batched_demo_feed(profile, opts \\ [])

  def batched_demo_feed(%{user_id: user_id} = _profile, opts) do
    batched_demo_feed(user_id, opts)
  end

  def batched_demo_feed(user_id, opts) do
    first_real = "00000177-679a-ad79-0242-ac1100030000"
    kj = "00000177-8336-5e0e-0242-ac1100030000"

    already_liked = ProfileLike |> where(by_user_id: ^user_id) |> select([s], s.user_id)

    real =
      Profile
      |> where([p], p.user_id != ^user_id)
      |> where([p], p.user_id != ^kj)
      |> where([p], p.user_id >= ^first_real)
      |> where([p], p.user_id not in subquery(already_liked))
      |> where([p], not p.hidden?)
      |> select([p], p.user_id)
      |> Repo.all()
      |> Enum.shuffle()

    fakes =
      Profile
      |> where([p], p.user_id < ^first_real)
      |> where([p], p.user_id not in subquery(already_liked))
      |> where([p], p.gender == "F")
      |> maybe_limit(opts[:fakes_count])
      |> select([p], p.user_id)
      # |> order_by([p], desc: p.user_id)
      |> Repo.all()
      |> Enum.shuffle()

    ids = real ++ fakes
    batched_demo_feed_cont(ids, user_id, opts)
  end

  @doc "batched_demo_feed_cont([<user-id>], <user-id>, loaded: 13)"
  def batched_demo_feed_cont(next_ids, user_id, opts) when is_list(next_ids) do
    loaded_count = opts[:loaded] || 10
    {to_fetch, next_ids} = Enum.split(next_ids, loaded_count)

    seen = SeenProfile |> where(by_user_id: ^user_id)

    loaded =
      Profile
      |> where([p], p.user_id in ^to_fetch)
      |> join(:left, [p], s in subquery(seen), on: p.user_id == s.user_id)
      |> select([p, s], %Profile{p | seen?: not is_nil(s.user_id)})
      |> Repo.all()

    %{loaded: loaded, next_ids: next_ids}
  end

  defp maybe_limit(query, nil), do: query
  defp maybe_limit(query, limit), do: limit(query, ^limit)

  defp get_feed(profile, date, opts) do
    feed =
      Feed
      |> where(user_id: ^profile.user_id)
      |> where(date: ^date)
      |> Repo.one()

    if feed, do: load_users_for_feed(feed, profile, date, opts)
  end

  # TODO test seen profiles are not loaded
  defp load_users_for_feed(%Feed{profiles: profiles}, profile, _date, opts)
       when is_map(profiles) do
    q = where(Profile, [p], p.user_id in ^Map.keys(profiles))

    q =
      if opts[:keep_seen?] do
        q
      else
        seen = SeenProfile |> where(by_user_id: ^profile.user_id) |> select([s], s.user_id)
        where(q, [p], p.user_id not in subquery(seen))
      end

    profiles =
      q
      |> Repo.all()
      |> Enum.map(fn profile ->
        %Profile{profile | feed_reason: profiles[profile.user_id]}
      end)

    # len = length(profiles)

    # if len == 5 do
    profiles
    # else
    #   profiles ++ create_feed(5 - len, profile, date)
    # end
  end

  defp with_reason(profiles, reason) do
    Enum.map(profiles, fn profile -> %Profile{profile | feed_reason: reason} end)
  end

  # TODO optimise query
  defp create_feed(profile, date) do
    seen = SeenProfile |> where(by_user_id: ^profile.user_id) |> select([s], s.user_id)

    common_q =
      Profile
      # not self
      |> where([p], p.user_id != ^profile.user_id)
      |> where(hidden?: false)
      |> where(city: ^profile.city)
      # TODO is there a better way?
      |> where([p], p.user_id not in subquery(seen))

    common_q = where(common_q, [p], p.gender in ^genders(profile))

    # place_1 and place_2
    most_liked =
      common_q
      |> order_by([p], desc: p.times_liked)
      |> limit(2)
      |> Repo.all()
      |> with_reason("most liked")

    filter_out_ids = Enum.map(most_liked, & &1.user_id)

    most_overlap =
      common_q
      |> join(:inner, [p], po in PersonalityOverlap,
        on:
          (p.user_id == po.user_id_1 and po.user_id_2 == ^profile.user_id) or
            (p.user_id == po.user_id_2 and po.user_id_1 == ^profile.user_id)
      )
      |> order_by([p, po], desc: po.score)
      |> where([p], p.user_id not in ^filter_out_ids)
      |> limit(1)
      |> Repo.all()
      |> with_reason("most overlap")

    filter_out_ids = filter_out_ids ++ Enum.map(most_overlap, & &1.user_id)

    likers =
      common_q
      |> join(:inner, [p], pl in ProfileLike,
        on: p.user_id == pl.by_user_id and pl.user_id == ^profile.user_id
      )
      |> join(:left, [p, pl], po in PersonalityOverlap,
        on:
          (p.user_id == po.user_id_1 and pl.by_user_id == po.user_id_2) or
            (p.user_id == po.user_id_2 and pl.by_user_id == po.user_id_1)
      )
      |> order_by([..., po], desc_nulls_last: po.score)
      |> where([p], p.user_id not in ^filter_out_ids)
      |> limit(2)
      |> Repo.all()
      |> with_reason("has liked with (possible) overlap")

    filter_out_ids = filter_out_ids ++ Enum.map(likers, & &1.user_id)

    non_rated =
      common_q
      |> where([p], p.times_liked == 0)
      |> where([p], p.user_id not in ^filter_out_ids)
      |> join(:left, [p], po in PersonalityOverlap,
        on:
          (p.user_id == po.user_id_1 and po.user_id_2 == ^profile.user_id) or
            (p.user_id == po.user_id_2 and po.user_id_1 == ^profile.user_id)
      )
      |> order_by([p, po], desc_nulls_last: po.score)
      |> limit(2)
      |> Repo.all()
      |> with_reason("non rated with (possible) overlap")

    filter_out_ids = filter_out_ids ++ Enum.map(non_rated, & &1.user_id)

    filler =
      case non_rated do
        [_, _] ->
          non_rated

        [_] ->
          non_rated ++
            (common_q
             |> where([p], p.user_id not in ^filter_out_ids)
             |> limit(1)
             |> Repo.all()
             |> with_reason("random"))

        [] ->
          common_q
          |> where([p], p.user_id not in ^filter_out_ids)
          |> limit(2)
          |> Repo.all()
          |> with_reason("random")
      end

    rest =
      case likers do
        [_place_4, _place_5] -> likers
        [place_4] -> [place_4, List.first(filler)]
        [] -> filler
      end

    profiles = most_liked ++ most_overlap ++ rest

    {:ok, _feed} =
      Repo.insert(%Feed{
        user_id: profile.user_id,
        date: date,
        profiles:
          Map.new(profiles, fn %Profile{user_id: id, feed_reason: reason} -> {id, reason} end)
      })

    profiles
  end

  defp genders(%Profile{filters: %Profile.Filters{genders: genders}}) when is_list(genders),
    do: genders

  defp genders(%Profile{gender: "F"}), do: ["M"]
  defp genders(%Profile{gender: "M"}), do: ["F"]
  defp genders(_other), do: []
end
