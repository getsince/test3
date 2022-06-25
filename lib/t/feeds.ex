defmodule T.Feeds do
  @moduledoc "Profile feeds for the app."

  import Ecto.{Query, Changeset}
  alias Ecto.Multi
  import Geo.PostGIS

  require Logger

  import T.Cluster, only: [primary_rpc: 3]

  alias T.Repo

  alias T.Accounts.UserReport
  alias T.Matches.{Match, Like}
  alias T.Feeds.{FeedProfile, SeenProfile, FeededProfile, FeedLimit}
  alias T.PushNotifications.DispatchJob
  alias T.Bot

  ### PubSub

  # TODO optimise pubsub:
  # instead of single topic, use `up-to-filter` with each subscriber providing a value up to which
  # they are subscribed, and if the event is below that value -> send it, if not -> don't send it

  @pubsub T.PubSub
  @topic "__f"

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

  ### Feed

  @feed_daily_limit 15
  # @feed_limit_recovery_period 24 * 60 * 60
  @feed_limit_recovery_period 2 * 60

  # TODO refactor
  @spec fetch_feed(
          Ecto.UUID.t(),
          Geo.Point.t(),
          pos_integer,
          String.t() | nil
        ) :: [%FeedProfile{}] | DateTime.t()
  # TODO remove writes
  def fetch_feed(user_id, location, feed_count, feed_cursor) do
    feed_limit = FeedLimit |> where(user_id: ^user_id) |> Repo.one()
    
    case feed_limit do
      nil ->
        feeded_count = feeded_profiles_count(user_id)

        cond do
          feeded_count >= @feed_daily_limit ->
            {:ok, %FeedLimit{timestamp: timestamp}} = insert_feed_limit(user_id)
            timestamp |> DateTime.add(@feed_limit_recovery_period)

          true ->
            count = min(feed_count, @feed_daily_limit - feeded_count)

            {profiles, cursor} =
              continue_feed(user_id, location, gender, feed_filter, count, feed_cursor)

            mark_profiles_feeded(user_id, profiles)

            {profiles, cursor}
        end

      %FeedLimit{timestamp: timestamp} ->
        timestamp |> DateTime.add(@feed_limit_recovery_period)
    end
  end

  defp feeded_profiles_count(user_id) do
    FeededProfile
    |> where(for_user_id: ^user_id)
    |> select([s], count(s.user_id))
    |> Repo.all()
  end

  defp insert_feed_limit(user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    %FeedLimit{user_id: user_id, timestamp: now} |> Repo.insert()
  end

  defp continue_feed(user_id, location, count, cursor) do
    feeded = FeededProfile |> where(for_user_id: ^user_id) |> select([s], s.user_id)

    feed_profiles_q(user_id)
    |> where([p], p.user_id not in subquery(feeded))
    |> order_by(fragment("location <-> ?::geometry", ^location))
    |> limit(^count)
    |> select([p], %{p | distance: distance_km(^location, p.location)})
    |> Repo.all()
  end

  defp empty_feeded_profiles(user_id) do
    primary_rpc(__MODULE__, :local_empty_feeded_profiles, [user_id])
  end

  @doc false
  def local_empty_feeded_profiles(user_id) do
    FeededProfile |> where(for_user_id: ^user_id) |> Repo.delete_all()
  end

  defp mark_profiles_feeded(for_user_id, feed_profiles) do
    feeded_user_ids = Enum.map(feed_profiles, fn profile -> profile.user_id end)
    primary_rpc(__MODULE__, :local_mark_profiles_feeded, [for_user_id, feeded_user_ids])
  end

  @doc false
  def local_mark_profiles_feeded(for_user_id, feeded_user_ids) do
    data =
      Enum.map(feeded_user_ids, fn feeded_user_id ->
        %{for_user_id: for_user_id, user_id: feeded_user_id}
      end)

    Repo.insert_all(FeededProfile, data, on_conflict: :nothing)
  end

  @spec get_mate_feed_profile(Ecto.UUID.t(), Geo.Point.t()) :: %FeedProfile{} | nil
  def get_mate_feed_profile(user_id, location) do
    not_hidden_profiles_q()
    |> where(user_id: ^user_id)
    |> select([p], %{p | distance: distance_km(^location, p.location)})
    |> Repo.one()
  end

  defp feed_profiles_q(user_id) do
    treshold_date = DateTime.utc_now() |> DateTime.add(-60 * 24 * 60 * 60, :second)

    filtered_profiles_q(user_id)
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

  defp filtered_profiles_q(user_id) do
    not_hidden_profiles_q()
    |> not_reported_profiles_q(user_id)
    |> not_liked_profiles_q(user_id)
    |> not_liker_profiles_q(user_id)
    |> not_seen_profiles_q(user_id)
  end

  ### Onboarding Feed

  def fetch_onboarding_feed(remote_ip, likes_count_treshold \\ 50) do
    location =
      case remote_ip do
        nil ->
          nil

        _ ->
          case T.Location.location_from_ip(remote_ip) do
            [lat, lon] -> %Geo.Point{coordinates: {lon, lat}, srid: 4326}
            _ -> nil
          end
      end

    people_nearby = profiles_near_location(location, 4)
    feeded_ids = people_nearby |> Enum.map(fn %FeedProfile{user_id: user_id} -> user_id end)

    most_popular_females =
      most_popular_profiles_with_genders(["F"], likes_count_treshold, feeded_ids, 3)

    most_popular_non_females =
      most_popular_profiles_with_genders(["M", "N"], likes_count_treshold, feeded_ids, 3)

    people_nearby ++ most_popular_females ++ most_popular_non_females
  end

  defp profiles_near_location(location, limit) do
    not_hidden_profiles_q()
    |> where([p], st_dwithin_in_meters(^location, p.location, ^1_000_000))
    |> order_by(desc: :like_ratio)
    |> limit(^limit)
    |> Repo.all()
  end

  defp most_popular_profiles_with_genders(genders, likes_count_treshold, feeded_ids, limit) do
    not_hidden_profiles_q()
    |> where([p], p.user_id not in ^feeded_ids)
    |> where([p], p.times_liked >= ^likes_count_treshold)
    |> where([p], p.gender in ^genders)
    |> order_by(desc: :like_ratio)
    |> limit(^limit)
    |> Repo.all()
  end

  ### Likes

  # TODO accept cursor
  @spec list_received_likes(Ecto.UUID.t(), Geo.Point.t()) :: [
          %{profile: %FeedProfile{}, seen: boolean()}
        ]
  def list_received_likes(user_id, location) do
    profiles_q = not_reported_profiles_q(user_id)

    Like
    |> where(user_id: ^user_id)
    |> where([l], is_nil(l.declined))
    |> not_match1_profiles_q(user_id)
    |> not_match2_profiles_q(user_id)
    |> order_by(desc: :inserted_at)
    |> join(:inner, [l], p in subquery(profiles_q), on: p.user_id == l.by_user_id)
    |> select([l, p], %{
      profile: %{p | distance: distance_km(^location, p.location)},
      seen: l.seen
    })
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
    primary_rpc(__MODULE__, :local_mark_profile_seen, [by_user_id, user_id])
  end

  @doc false
  def local_mark_profile_seen(by_user_id, user_id) do
    seen_changeset(by_user_id, user_id)
    |> Repo.insert()
    |> local_maybe_bump_shown_count(user_id)
  end

  defp seen_changeset(by_user_id, user_id) do
    %SeenProfile{by_user_id: by_user_id, user_id: user_id}
    |> change()
    |> unique_constraint(:seen, name: :seen_profiles_pkey)
  end

  defp local_maybe_bump_shown_count(repo, user_id) do
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

  def local_prune_seen_profiles(ttl_days) do
    SeenProfile
    |> where([s], s.inserted_at < fragment("now() - ? * interval '1 day'", ^ttl_days))
    |> Repo.delete_all()
  end

  ### Feed limits

  def feed_limits_prune(reference \\ DateTime.utc_now()) do
    reference
    |> list_recovered_feed_limits()
    |> Enum.each(fn user_id -> local_reset_feed_limit(user_id) end)
  end

  defp list_recovered_feed_limits(reference) do
    recovery_date = DateTime.add(reference, -@feed_limit_recovery_period)

    FeedLimit
    |> where([l], l.timestamp < ^recovery_date)
    |> select([l], l.user_id)
    |> Repo.all()
  end

  @spec local_reset_feed_limit(Ecto.UUID.t()) :: :ok
  def local_reset_feed_limit(user_id) do
    m = "feed limit of #{user_id} was reset"

    Logger.warn(m)
    Bot.async_post_message(m)

    Multi.new()
    |> Multi.delete_all(:reset_feed_limit, FeedLimit |> where(user_id: ^user_id))
    |> Multi.run(:push, fn _repo, _changes ->
      push_job = DispatchJob.new(%{"type" => "feed_limit_reset", "user_id" => user_id})

      Oban.insert(push_job)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, _result} -> broadcast_for_user(user_id, {__MODULE__, :feed_limit_reset})
      {:error, _error} -> nil
    end

    :ok
  end
end
