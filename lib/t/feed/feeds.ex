defmodule T.Feeds do
  import Ecto.Query
  alias T.Repo
  alias T.Accounts.Profile
  alias T.Feeds.{Feed, SeenProfile, ProfileLike, ProfileDislike, PersonalityOverlap}
  alias T.Matches.Match

  @pubsub T.PubSub
  @topic to_string(__MODULE__)

  defp topic(user_id) do
    @topic <> ":" <> user_id
  end

  @doc false
  def subscribe do
    Phoenix.PubSub.subscribe(@pubsub, @topic)
  end

  def subscribe(user_id) do
    Phoenix.PubSub.subscribe(@pubsub, topic(user_id))
  end

  defp notify_subscribers(
         {:ok, %Match{user_id_1: uid1, user_id_2: uid2} = match} = success,
         [:matched]
       ) do
    for topic <- [topic(uid1), topic(uid2)] do
      Phoenix.PubSub.broadcast(@pubsub, topic, {__MODULE__, [:matched], match})
    end

    success
  end

  defp notify_subscribers({:ok, nil} = no_match, [:matched]) do
    no_match
  end

  # TODO auth, check they are in our feed, check no more 5 per day
  def like_profile(by_user_id, user_id) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:seen, %SeenProfile{by_user_id: by_user_id, user_id: user_id})
    |> Ecto.Multi.insert(:like, %ProfileLike{by_user_id: by_user_id, user_id: user_id})
    |> Ecto.Multi.run(:times_liked_inc, fn repo, _changes ->
      {1, nil} =
        Profile
        |> where(user_id: ^user_id)
        |> repo.update_all(inc: [times_liked: 1])

      {:ok, nil}
    end)
    |> Ecto.Multi.run(:maybe_match, fn repo, _changes ->
      liked? =
        ProfileLike
        |> where(user_id: ^by_user_id)
        |> where(by_user_id: ^user_id)
        |> repo.exists?()

      if liked? do
        {2, nil} =
          Profile
          |> where([p], p.user_id in ^[by_user_id, user_id])
          |> repo.update_all(set: [hidden?: true])

        create_match(repo, [by_user_id, user_id])
      else
        {:ok, nil}
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{maybe_match: %Match{} = match}} -> {:ok, match}
      {:ok, %{maybe_match: nil}} -> {:ok, nil}
    end
    |> notify_subscribers([:matched])
  end

  defp create_match(repo, user_ids) do
    [user_id_1, user_id_2] = Enum.sort(user_ids)
    repo.insert(%Match{user_id_1: user_id_1, user_id_2: user_id_2, alive?: true})
  end

  # TODO check if user_id is in feed, check no more 5 per day
  def dislike_profile(by_user_id, user_id) do
    {:ok, _changes} =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:seen, %SeenProfile{by_user_id: by_user_id, user_id: user_id})
      |> Ecto.Multi.insert(:dislike, %ProfileDislike{by_user_id: by_user_id, user_id: user_id})
      |> Repo.transaction()

    :ok
  end

  def get_or_create_feed(%Profile{} = profile, date \\ Date.utc_today()) do
    {:ok, profiles} =
      Repo.transaction(fn -> get_feed(profile, date) || create_feed(profile, date) end)

    Enum.shuffle(profiles)
  end

  defp get_feed(profile, date) do
    feed =
      Feed
      |> where(user_id: ^profile.user_id)
      |> where(date: ^date)
      |> Repo.one()

    if feed, do: load_users_for_feed(feed, profile, date)
  end

  defp load_users_for_feed(%Feed{profiles: profiles}, _profile, _date)
       when is_map(profiles) do
    profiles =
      Profile
      |> where([p], p.user_id in ^Map.keys(profiles))
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
      |> with_cte("seen", as: ^seen)
      # not self
      |> where([p], p.user_id != ^profile.user_id)
      |> where(gender: ^opposite_gender(profile))
      |> where(hidden?: false)
      |> where([p], p.user_id not in subquery(from s in "seen", select: s.user_id))

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
        on: p.user_id == po.user_id_1 or p.user_id == po.user_id_2
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
        on: p.user_id == po.user_id_1 or p.user_id == po.user_id_2
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

  def opposite_gender(%Profile{gender: gender}), do: opposite_gender(gender)
  def opposite_gender("F"), do: "M"
  def opposite_gender("M"), do: "F"
end
