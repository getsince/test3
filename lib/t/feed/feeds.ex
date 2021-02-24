defmodule T.Feeds do
  import Ecto.{Query, Changeset}

  alias T.{Repo, PushNotifications}
  alias T.Accounts.Profile
  alias T.Feeds.{Feed, SeenProfile, ProfileLike, PersonalityOverlap}
  alias T.Matches.Match

  @pubsub T.PubSub
  @topic to_string(__MODULE__)

  @doc false
  def topic(user_id) do
    @topic <> ":" <> String.downcase(user_id)
  end

  @doc false
  def subscribe do
    Phoenix.PubSub.subscribe(@pubsub, @topic)
  end

  def subscribe(user_id) do
    Phoenix.PubSub.subscribe(@pubsub, topic(user_id))
  end

  defp notify_subscribers(
         {:ok, %Match{user_id_1: uid1, user_id_2: uid2, alive?: true} = match} = success,
         [:matched]
       ) do
    for topic <- [topic(uid1), topic(uid2)] do
      Phoenix.PubSub.broadcast(@pubsub, topic, {__MODULE__, [:matched], match})
    end

    success
  end

  defp notify_subscribers({:ok, _other} = no_active_match, [:matched]) do
    no_active_match
  end

  defp notify_subscribers({:error, _reason} = failure, _event) do
    failure
  end

  def mark_seen(by_user_id, user_id) do
    %SeenProfile{by_user_id: by_user_id, user_id: user_id}
    |> change()
    |> unique_constraint(:seen, name: :seen_profiles_pkey)
    |> Repo.insert()
  end

  def mark_liked(by_user_id, user_id) do
    Repo.insert(%ProfileLike{by_user_id: by_user_id, user_id: user_id})
  end

  def bump_likes_count(user_id) do
    {1, [count]} =
      Profile
      |> where(user_id: ^user_id)
      |> select([p], p.times_liked)
      |> Repo.update_all(inc: [times_liked: 1])

    {:ok, count}
  end

  def match_if_mutual(by_user_id, user_id) do
    ProfileLike
    # if I am liked
    |> where(user_id: ^by_user_id)
    # by who I liked
    |> where(by_user_id: ^user_id)
    |> join(:inner, [pl], p in Profile, on: p.user_id == pl.by_user_id)
    # and who I liked is not hidden
    |> select([..., p], p.hidden?)
    |> Repo.one()
    |> case do
      # nobody likes me, sad
      _no_liker = nil ->
        {:ok, nil}

      # someone likes me, and they are not hidden! meaning they are
      # - not fully matched
      # - not pending deletion
      # - not blocked
      _not_hidden = false ->
        create_match([by_user_id, user_id])

      # somebody likes me, but they are hidden -> like is discarded
      _hidden = true ->
        {:ok, nil}
    end
  end

  defp create_match(user_ids) when is_list(user_ids) do
    [user_id_1, user_id_2] = Enum.sort(user_ids)
    Repo.insert(%Match{user_id_1: user_id_1, user_id_2: user_id_2, alive?: true})
  end

  def profiles_with_match_count(user_ids) do
    profiles_with_match_count_q(user_ids)
    |> Repo.all()
    |> Map.new(fn %{user_id: id, count: count} -> {id, count} end)
  end

  # TODO bench, ensure doesn't slow down with more unmatches
  defp profiles_with_match_count_q(user_ids) when is_list(user_ids) do
    Profile
    |> where([p], p.user_id in ^user_ids)
    |> join(:left, [p], m in Match, on: p.user_id in [m.user_id_1, m.user_id_2] and m.alive?)
    |> group_by([p], p.user_id)
    |> select([p, m], %{user_id: p.user_id, count: count(m.id)})
  end

  def hide_profiles(user_ids, max_match_count \\ 3) do
    profiles_with_match_count = profiles_with_match_count_q(user_ids)

    {_count, hidden} =
      Profile
      |> join(:inner, [p], c in subquery(profiles_with_match_count),
        on: c.count >= ^max_match_count and p.user_id == c.user_id
      )
      |> select([p], p.user_id)
      |> Repo.update_all(set: [hidden?: true])

    hidden
  end

  def schedule_notify(%Match{alive?: true, id: match_id}) do
    job = PushNotifications.DispatchJob.new(%{"type" => "match", "match_id" => match_id})
    Oban.insert(job)
  end

  # TODO forbid liking if more than 3 active matches? or rather if hidden?
  # TODO auth, check they are in our feed, check no more than 5 per day
  def like_profile(by_user_id, user_id) do
    Repo.transact(fn ->
      with {:ok, _seen} <- mark_seen(by_user_id, user_id),
           {:ok, _like} <- mark_liked(by_user_id, user_id),
           {:ok, _count} <- bump_likes_count(user_id),
           {:ok, maybe_match} <- match_if_mutual(by_user_id, user_id) do
        if maybe_match do
          {:ok, _job} = schedule_notify(maybe_match)
          _hidden = hide_profiles([by_user_id, user_id])
        end

        {:ok, maybe_match}
      end
    end)
    |> notify_subscribers([:matched])
  end

  def get_or_create_feed(%Profile{} = profile, date \\ Date.utc_today(), opts \\ []) do
    {:ok, profiles} =
      Repo.transaction(fn -> get_feed(profile, date, opts) || create_feed(profile, date) end)

    Enum.shuffle(profiles)
  end

  def use_demo_feed(use?) when is_boolean(use?) do
    Application.put_env(:t, :use_demo_feed?, use?)
  end

  def use_demo_feed? do
    !!Application.get_env(:t, :use_demo_feed?)
  end

  def demo_feed do
    user_ids = [
      "00000177-8ae4-b4c4-0242-ac1100030000",
      "00000177-830a-a7d0-0242-ac1100030000",
      "00000177-82ed-c4c9-0242-ac1100030000",
      "00000177-809e-4ef7-0242-ac1100030000",
      "00000177-7d1f-61be-0242-ac1100030000"
    ]

    real =
      Profile
      |> where([p], p.user_id in ^user_ids)
      |> Repo.all()
      |> Enum.shuffle()

    girls =
      Profile
      |> where([p], p.user_id not in ^user_ids)
      |> where([p], p.gender == "F")
      |> limit(100)
      |> Repo.all()
      |> Enum.shuffle()

    real ++ girls
  end

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
      |> where(gender: ^opposite_gender(profile))
      |> where(hidden?: false)
      |> where(city: ^profile.city)
      # TODO is there a better way?
      |> where([p], p.user_id not in subquery(seen))

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

  # TODO
  def opposite_gender(%Profile{gender: gender}), do: opposite_gender(gender)
  def opposite_gender("F"), do: "M"
  def opposite_gender("M"), do: "F"
end
