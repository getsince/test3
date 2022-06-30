defmodule T.Feeds do
  @moduledoc "Profile feeds for the app."

  import Ecto.{Query, Changeset}
  alias Ecto.Multi
  import Geo.PostGIS
  import T.Gettext

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

  @feed_fetch_count 10
  @feed_daily_limit 50
  @feed_limit_period 12 * 60 * 60

  # TODO refactor
  @spec fetch_feed(
          Ecto.UUID.t(),
          Geo.Point.t(),
          String.t() | nil
        ) :: [%FeedProfile{}] | {DateTime.t(), map}
  # TODO remove writes
  def fetch_feed(user_id, location, first_fetch) do
    feed_limit = FeedLimit |> where(user_id: ^user_id) |> Repo.one()

    case feed_limit do
      %FeedLimit{timestamp: timestamp} ->
        reset_timestamp = timestamp |> DateTime.add(@feed_limit_period)
        {reset_timestamp, feed_limit_story(T.Matches.has_matches(user_id))}

      nil ->
        seen_and_feeded_ids = seen_and_feeded_ids(user_id)

        cond do
          length(seen_and_feeded_ids) >= @feed_daily_limit ->
            %FeedLimit{timestamp: timestamp} = insert_feed_limit(user_id)
            reset_timestamp = timestamp |> DateTime.add(@feed_limit_period)
            {reset_timestamp, feed_limit_story(T.Matches.has_matches(user_id))}

          true ->
            adjusted_count =
              min(@feed_daily_limit - length(seen_and_feeded_ids), @feed_fetch_count)

            continue_feed(user_id, location, adjusted_count, first_fetch)
        end
    end
  end

  defp seen_and_feeded_ids(user_id) do
    feed_limit_treshold_date =
      DateTime.utc_now() |> DateTime.add(-@feed_limit_period) |> DateTime.truncate(:second)

    seen_query =
      SeenProfile
      |> where(by_user_id: ^user_id)
      |> where([s], s.inserted_at > ^feed_limit_treshold_date)
      |> select([s], s.user_id)

    FeededProfile
    |> where(for_user_id: ^user_id)
    |> where([s], s.inserted_at > ^feed_limit_treshold_date)
    |> select([s], s.user_id)
    |> union(^seen_query)
    |> Repo.all()
  end

  defp insert_feed_limit(user_id) do
    m = "#{user_id} reached feed limit"

    Logger.warn(m)
    Bot.async_post_message(m)

    now = DateTime.utc_now() |> DateTime.truncate(:second)
    %FeedLimit{user_id: user_id, timestamp: now} |> Repo.insert!()
  end

  defp continue_feed(user_id, location, count, first_fetch) do
    feeded_ids =
      FeededProfile |> where(for_user_id: ^user_id) |> select([f], f.user_id) |> Repo.all()

    if first_fetch do
      previously_feeded_profiles =
        FeedProfile
        |> where([p], p.user_id in ^feeded_ids)
        |> limit(^count)
        |> select([p], %{p | distance: distance_km(^location, p.location)})
        |> Repo.all()

      adjusted_count = max(0, count - length(previously_feeded_profiles))

      feed_profiles =
        feed_profiles_q(user_id)
        |> where([p], p.user_id not in ^feeded_ids)
        |> order_by(fragment("location <-> ?::geometry", ^location))
        |> limit(^adjusted_count)
        |> select([p], %{p | distance: distance_km(^location, p.location)})
        |> Repo.all()

      mark_profiles_feeded(user_id, feed_profiles)
      previously_feeded_profiles ++ feed_profiles
    else
      feed_profiles =
        feed_profiles_q(user_id)
        |> where([p], p.user_id not in ^feeded_ids)
        |> order_by(fragment("location <-> ?::geometry", ^location))
        |> limit(^count)
        |> select([p], %{p | distance: distance_km(^location, p.location)})
        |> Repo.all()

      mark_profiles_feeded(user_id, feed_profiles)
      feed_profiles
    end
  end

  defp mark_profiles_feeded(for_user_id, feed_profiles) do
    feeded_user_ids = Enum.map(feed_profiles, fn profile -> profile.user_id end)
    primary_rpc(__MODULE__, :local_mark_profiles_feeded, [for_user_id, feeded_user_ids])
  end

  @doc false
  def local_mark_profiles_feeded(for_user_id, feeded_user_ids) do
    inserted_at = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_naive()

    data =
      Enum.map(feeded_user_ids, fn feeded_user_id ->
        %{for_user_id: for_user_id, user_id: feeded_user_id, inserted_at: inserted_at}
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
    Multi.new()
    |> Multi.insert(:seen_profile, seen_changeset(by_user_id, user_id))
    |> Multi.delete_all(
      :delete_feeded_profile,
      FeededProfile |> where(for_user_id: ^by_user_id, user_id: ^user_id)
    )
    |> Repo.transaction()
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

      {:error, _, _, _} = error ->
        error
    end
  end

  def local_prune_seen_profiles(ttl_days) do
    SeenProfile
    |> where([s], s.inserted_at < fragment("now() - ? * interval '1 day'", ^ttl_days))
    |> Repo.delete_all()
  end

  ### Feed limits

  defp feed_limit_story(has_matches) do
    now_you_can_do_label =
      if has_matches do
        %{
          "zoom" => 0.7091569071880537,
          "value" => dgettext("feeds", "а пока можешь пообщаться \nс мэтчами"),
          "position" => [25.74864426013174, 484.3437057898561],
          "rotation" => -10.167247449849249,
          "alignment" => 1,
          "text_color" => "#FFFFFF",
          "corner_radius" => 0,
          "background_fill" => "#6D42B1"
        }
      else
        %{
          "zoom" => 0.7091569071880537,
          "value" => dgettext("feeds", "а пока можешь поработать \nнад своим профилем"),
          "position" => [176.7486442601318, 506.01036228399676],
          "rotation" => 10.167247449849249,
          "alignment" => 1,
          "text_color" => "#FFFFFF",
          "corner_radius" => 0,
          "background_fill" => "#49BDB5"
        }
      end

    drawing_lines =
      if has_matches do
        "W3sicG9pbnRzIjpbWzI4Ny42NjY2NTY0OTQxNDA2Miw0OTMuNjY2NjU2NDk0MTQwNjJdLFsyODguNjY2NjU2NDk0MTQwNjIsNDkzLjY2NjY1NjQ5NDE0MDYyXSxbMjkyLjMzMzMyODI0NzA3MDMxLDQ5My42NjY2NTY0OTQxNDA2Ml0sWzI5OS42NjY2NTY0OTQxNDA2Miw0OTNdLFszMTAuMzMzMzI4MjQ3MDcwMzEsNDkxXSxbMzE5LjMzMzMyODI0NzA3MDMxLDQ4OC42NjY2NTY0OTQxNDA2Ml0sWzMzMC4zMzMzMjgyNDcwNzAzMSw0ODZdLFszNDMsNDgyLjY2NjY1NjQ5NDE0MDYyXSxbMzUyLjMzMzMyODI0NzA3MDMxLDQ4MF0sWzM1Ny42NjY2NTY0OTQxNDA2Miw0NzguNjY2NjU2NDk0MTQwNjJdLFszNjUuMzMzMzI4MjQ3MDcwMzEsNDc2LjMzMzMyODI0NzA3MDMxXSxbMzcwLjMzMzMyODI0NzA3MDMxLDQ3NV0sWzM3OSw0NzIuNjY2NjU2NDk0MTQwNjJdLFszODYsNDcxXSxbMzg5LjY2NjY1NjQ5NDE0MDYyLDQ3MF0sWzM5NCw0NjldLFszOTYuMzMzMzI4MjQ3MDcwMzEsNDY4LjY2NjY1NjQ5NDE0MDYyXSxbMzk3LDQ2OC4zMzMzMjgyNDcwNzAzMV0sWzM5Ny4zMzMzMjgyNDcwNzAzMSw0NjguMzMzMzI4MjQ3MDcwMzFdLFszOTcuNjY2NjU2NDk0MTQwNjIsNDY4LjMzMzMyODI0NzA3MDMxXSxbMzk4LjMzMzMyODI0NzA3MDMxLDQ2OF0sWzM5OC42NjY2NTY0OTQxNDA2Miw0NjhdLFszOTgsNDY4XSxbMzk2LjY2NjY1NjQ5NDE0MDYyLDQ2OF0sWzM5NS4zMzMzMjgyNDcwNzAzMSw0NjhdLFszOTIsNDY4XSxbMzg5LjY2NjY1NjQ5NDE0MDYyLDQ2OF0sWzM4NSw0NjhdLFszNzUsNDY4XSxbMzcwLjMzMzMyODI0NzA3MDMxLDQ2OC42NjY2NTY0OTQxNDA2Ml0sWzM2Ny4zMzMzMjgyNDcwNzAzMSw0NjkuMzMzMzI4MjQ3MDcwMzFdLFszNjYsNDY5LjMzMzMyODI0NzA3MDMxXSxbMzY1LjY2NjY1NjQ5NDE0MDYyLDQ2OS4zMzMzMjgyNDcwNzAzMV0sWzM2Niw0NjkuMzMzMzI4MjQ3MDcwMzFdLFszNjYuNjY2NjU2NDk0MTQwNjIsNDY5LjMzMzMyODI0NzA3MDMxXSxbMzY3LjMzMzMyODI0NzA3MDMxLDQ2OS4zMzMzMjgyNDcwNzAzMV0sWzM3MC4zMzMzMjgyNDcwNzAzMSw0NjguNjY2NjU2NDk0MTQwNjJdLFszNzIuNjY2NjU2NDk0MTQwNjIsNDY4LjMzMzMyODI0NzA3MDMxXSxbMzc3LjMzMzMyODI0NzA3MDMxLDQ2Ny42NjY2NTY0OTQxNDA2Ml0sWzM4Myw0NjcuNjY2NjU2NDk0MTQwNjJdLFszODYuNjY2NjU2NDk0MTQwNjIsNDY3LjMzMzMyODI0NzA3MDMxXSxbMzkwLjMzMzMyODI0NzA3MDMxLDQ2Ny4zMzMzMjgyNDcwNzAzMV0sWzM5Mi4zMzMzMjgyNDcwNzAzMSw0NjcuMzMzMzI4MjQ3MDcwMzFdLFszOTUsNDY3LjMzMzMyODI0NzA3MDMxXSxbMzk1LjY2NjY1NjQ5NDE0MDYyLDQ2Ny4zMzMzMjgyNDcwNzAzMV0sWzM5Ni4zMzMzMjgyNDcwNzAzMSw0NjcuMzMzMzI4MjQ3MDcwMzFdLFszOTYuNjY2NjU2NDk0MTQwNjIsNDY3LjMzMzMyODI0NzA3MDMxXSxbMzk3LDQ2Ny4zMzMzMjgyNDcwNzAzMV0sWzM5Ny4zMzMzMjgyNDcwNzAzMSw0NjcuMzMzMzI4MjQ3MDcwMzFdLFszOTcuNjY2NjU2NDk0MTQwNjIsNDY3LjY2NjY1NjQ5NDE0MDYyXSxbMzk3LjY2NjY1NjQ5NDE0MDYyLDQ2OF0sWzM5Ny4zMzMzMjgyNDcwNzAzMSw0NjguMzMzMzI4MjQ3MDcwMzFdLFszOTYsNDY5XSxbMzk0LDQ3MV0sWzM5Mi42NjY2NTY0OTQxNDA2Miw0NzIuMzMzMzI4MjQ3MDcwMzFdLFszOTEsNDc0LjMzMzMyODI0NzA3MDMxXSxbMzg5LjY2NjY1NjQ5NDE0MDYyLDQ3NS42NjY2NTY0OTQxNDA2Ml0sWzM4OCw0NzcuMzMzMzI4MjQ3MDcwMzFdLFszODYuMzMzMzI4MjQ3MDcwMzEsNDc5LjMzMzMyODI0NzA3MDMxXSxbMzg1LDQ4MC42NjY2NTY0OTQxNDA2Ml0sWzM4NCw0ODEuNjY2NjU2NDk0MTQwNjJdLFszODMuMzMzMzI4MjQ3MDcwMzEsNDgyLjMzMzMyODI0NzA3MDMxXSxbMzgzLDQ4M10sWzM4Mi42NjY2NTY0OTQxNDA2Miw0ODNdLFszODIuMzMzMzI4MjQ3MDcwMzEsNDgzLjMzMzMyODI0NzA3MDMxXSxbMzgyLjMzMzMyODI0NzA3MDMxLDQ4My42NjY2NTY0OTQxNDA2Ml0sWzM4Miw0ODMuNjY2NjU2NDk0MTQwNjJdLFszODEuNjY2NjU2NDk0MTQwNjIsNDg0XSxbMzgxLjMzMzMyODI0NzA3MDMxLDQ4NC4zMzMzMjgyNDcwNzAzMV0sWzM4MSw0ODQuMzMzMzI4MjQ3MDcwMzFdLFszODAuNjY2NjU2NDk0MTQwNjIsNDg0LjY2NjY1NjQ5NDE0MDYyXSxbMzgwLjMzMzMyODI0NzA3MDMxLDQ4NC42NjY2NTY0OTQxNDA2Ml0sWzM4MC4zMzMzMjgyNDcwNzAzMSw0ODVdXSwic3Ryb2tlX2NvbG9yIjoiIzZENDJCMSIsInN0cm9rZV93aWR0aCI6Mi41fV0="
      else
        "W3sicG9pbnRzIjpbWzE2Miw1MjNdLFsxNjEsNTIzXSxbMTUyLjY2NjY1NjQ5NDE0MDYyLDUyM10sWzE0NS4zMzMzMjgyNDcwNzAzMSw1MjNdLFsxMzcuMzMzMzI4MjQ3MDcwMzEsNTIzXSxbMTE5LjMzMzMyODI0NzA3MDMxLDUyM10sWzExMS4zMzMzMjgyNDcwNzAzMSw1MjNdLFs5My4zMzMzMjgyNDcwNzAzMTIsNTIzXSxbODMsNTIzXSxbNzQuMzMzMzI4MjQ3MDcwMzEyLDUyM10sWzY1LjY2NjY1NjQ5NDE0MDYyNSw1MjNdLFs2MSw1MjNdLFs1NCw1MjNdLFs1MC4zMzMzMjgyNDcwNzAzMTIsNTIzXSxbNDgsNTIzXSxbNDcsNTIzXSxbNDYuNjY2NjU2NDk0MTQwNjI1LDUyM10sWzQ1LjMzMzMyODI0NzA3MDMxMiw1MjNdLFs0My4zMzMzMjgyNDcwNzAzMTIsNTIzXSxbNDIsNTIzXSxbMzkuNjY2NjU2NDk0MTQwNjI1LDUyM10sWzM4LjMzMzMyODI0NzA3MDMxMiw1MjNdLFszOCw1MjNdLFszNy4zMzMzMjgyNDcwNzAzMTIsNTIzXSxbMzcsNTIzXSxbMzcsNTIyLjY2NjY1NjQ5NDE0MDYyXSxbMzcuMzMzMzI4MjQ3MDcwMzEyLDUyMi4zMzMzMjgyNDcwNzAzMV0sWzM4LjMzMzMyODI0NzA3MDMxMiw1MjEuNjY2NjU2NDk0MTQwNjJdLFszOS42NjY2NTY0OTQxNDA2MjUsNTIxXSxbNDIsNTE5LjY2NjY1NjQ5NDE0MDYyXSxbNDQsNTE5XSxbNDYuNjY2NjU2NDk0MTQwNjI1LDUxOF0sWzUwLjMzMzMyODI0NzA3MDMxMiw1MTYuNjY2NjU2NDk0MTQwNjJdLFs1Myw1MTUuNjY2NjU2NDk0MTQwNjJdLFs1Ni4zMzMzMjgyNDcwNzAzMTIsNTE0LjY2NjY1NjQ5NDE0MDYyXSxbNTksNTEzLjY2NjY1NjQ5NDE0MDYyXSxbNjAuNjY2NjU2NDk0MTQwNjI1LDUxMy4zMzMzMjgyNDcwNzAzMV0sWzYyLDUxM10sWzYyLjY2NjY1NjQ5NDE0MDYyNSw1MTIuNjY2NjU2NDk0MTQwNjJdLFs2My4zMzMzMjgyNDcwNzAzMTIsNTEyLjMzMzMyODI0NzA3MDMxXSxbNjIuNjY2NjU2NDk0MTQwNjI1LDUxMi4zMzMzMjgyNDcwNzAzMV0sWzYxLjMzMzMyODI0NzA3MDMxMiw1MTIuNjY2NjU2NDk0MTQwNjJdLFs1OS4zMzMzMjgyNDcwNzAzMTIsNTEzLjY2NjY1NjQ5NDE0MDYyXSxbNTYuMzMzMzI4MjQ3MDcwMzEyLDUxNV0sWzUzLjMzMzMyODI0NzA3MDMxMiw1MTYuMzMzMzI4MjQ3MDcwMzFdLFs0OC42NjY2NTY0OTQxNDA2MjUsNTE4LjMzMzMyODI0NzA3MDMxXSxbNDUsNTIwXSxbNDEuNjY2NjU2NDk0MTQwNjI1LDUyMS4zMzMzMjgyNDcwNzAzMV0sWzM5LjMzMzMyODI0NzA3MDMxMiw1MjIuMzMzMzI4MjQ3MDcwMzFdLFszNyw1MjMuMzMzMzI4MjQ3MDcwMzFdLFszNSw1MjRdLFszMi4zMzMzMjgyNDcwNzAzMTIsNTI1XSxbMzAuNjY2NjU2NDk0MTQwNjI1LDUyNS42NjY2NTY0OTQxNDA2Ml0sWzMwLDUyNl0sWzI5LjY2NjY1NjQ5NDE0MDYyNSw1MjZdLFsyOS4zMzMzMjgyNDcwNzAzMTIsNTI2XSxbMjkuNjY2NjU2NDk0MTQwNjI1LDUyNl0sWzMwLDUyNl0sWzMwLjMzMzMyODI0NzA3MDMxMiw1MjYuMzMzMzI4MjQ3MDcwMzFdLFszMyw1MjcuMzMzMzI4MjQ3MDcwMzFdLFszNS42NjY2NTY0OTQxNDA2MjUsNTI4LjMzMzMyODI0NzA3MDMxXSxbNDMsNTMxLjMzMzMyODI0NzA3MDMxXSxbNDcuNjY2NjU2NDk0MTQwNjI1LDUzMy4zMzMzMjgyNDcwNzAzMV0sWzUyLjY2NjY1NjQ5NDE0MDYyNSw1MzUuMzMzMzI4MjQ3MDcwMzFdLFs1NS4zMzMzMjgyNDcwNzAzMTIsNTM2LjMzMzMyODI0NzA3MDMxXSxbNTcuMzMzMzI4MjQ3MDcwMzEyLDUzN10sWzU3LjY2NjY1NjQ5NDE0MDYyNSw1MzcuMzMzMzI4MjQ3MDcwMzFdLFs1OCw1MzcuMzMzMzI4MjQ3MDcwMzFdXSwic3Ryb2tlX2NvbG9yIjoiIzQ5QkRCNSIsInN0cm9rZV93aWR0aCI6Mi41fV0="
      end

    case Gettext.get_locale() do
      "ru" ->
        [
          %{
            "size" => [428, 926],
            "labels" => [
              %{
                "zoom" => 1,
                "value" => dgettext("feeds", "Пока это все \nдоступные профили 👀"),
                "position" => [75.61896702822253, 160.56426949136994],
                "rotation" => 0,
                "alignment" => 1,
                "text_color" => "#FFFFFF",
                "corner_radius" => 0,
                "background_fill" => "#111010"
              },
              %{
                "zoom" => 0.85,
                "value" => dgettext("feeds", "Новые появятся через"),
                "position" => [98.01755000000003, 294.9927156120549],
                "rotation" => 0,
                "alignment" => 1,
                "text_color" => "#FFFFFF",
                "corner_radius" => 1,
                "background_fill" => "#111010"
              },
              %{
                "zoom" => 0.681925669895563,
                "value" =>
                  dgettext(
                    "feeds",
                    "Мы за осознанный подход к \nзнакомствам — за каждым \nпрофилем скрывается \nинтересная  личность ✨"
                  ),
                "position" => [95.34884174656703, 700.7448955448994],
                "rotation" => 15.905945431577537,
                "alignment" => 1,
                "text_color" => "#FFFFFF",
                "corner_radius" => 0,
                "background_fill" => "#ED3D90"
              },
              now_you_can_do_label
            ],
            "drawing" => %{
              "lines" => drawing_lines
            },
            "background" => %{"color" => "#111010"}
          }
        ]

      # these differ slightly in sticker positions
      # TODO proper
      _ ->
        [
          %{
            "size" => [428, 926],
            "labels" => [
              %{
                "zoom" => 1,
                "value" => dgettext("feeds", "Пока это все \nдоступные профили 👀"),
                "position" => [65.39700000000002, 160.56426949136994],
                "rotation" => 0,
                "alignment" => 1,
                "text_color" => "#FFFFFF",
                "corner_radius" => 0,
                "background_fill" => "#111010"
              },
              %{
                "zoom" => 0.85,
                "value" => dgettext("feeds", "Новые появятся через"),
                "position" => [112.43992500000003, 294.9927156120549],
                "rotation" => 0,
                "alignment" => 1,
                "text_color" => "#FFFFFF",
                "corner_radius" => 1,
                "background_fill" => "#111010"
              },
              %{
                "zoom" => 0.681925669895563,
                "value" =>
                  dgettext(
                    "feeds",
                    "Мы за осознанный подход к \nзнакомствам — за каждым \nпрофилем скрывается \nинтересная  личность ✨"
                  ),
                "position" => [95.34884174656703, 700.7448955448994],
                "rotation" => 15.905945431577537,
                "alignment" => 1,
                "text_color" => "#FFFFFF",
                "corner_radius" => 0,
                "background_fill" => "#ED3D90"
              },
              now_you_can_do_label
            ],
            "drawing" => %{
              "lines" => drawing_lines
            },
            "background" => %{"color" => "#111010"}
          }
        ]
    end
  end

  def reached_limit(me, timestamp) do
    %FeedLimit{user_id: me, timestamp: timestamp}
    |> cast(%{reached: true}, [:reached])
    |> Repo.update()
  end

  def feed_limits_prune(reference \\ DateTime.utc_now()) do
    reference
    |> list_reset_feed_limits()
    |> Enum.each(fn %FeedLimit{} = feed_limit -> local_reset_feed_limit(feed_limit) end)
  end

  defp list_reset_feed_limits(reference) do
    reset_date = DateTime.add(reference, -@feed_limit_period)

    FeedLimit
    |> where([l], l.timestamp < ^reset_date)
    |> Repo.all()
  end

  @spec local_reset_feed_limit(%FeedLimit{}) :: :ok
  def local_reset_feed_limit(feed_limit) do
    m = "feed limit of #{feed_limit.user_id} was reset"

    Logger.warn(m)
    Bot.async_post_message(m)

    Multi.new()
    |> Multi.delete(:delete_feed_limit, feed_limit)
    |> maybe_schedule_push(feed_limit)
    |> Repo.transaction()
    |> case do
      {:ok, _result} -> broadcast_for_user(feed_limit.user_id, {__MODULE__, :feed_limit_reset})
      {:error, _error} -> nil
    end

    :ok
  end

  defp maybe_schedule_push(multi, %FeedLimit{user_id: user_id, reached: true}) do
    multi
    |> Multi.run(:push, fn _repo, _changes ->
      push_job = DispatchJob.new(%{"type" => "feed_limit_reset", "user_id" => user_id})
      Oban.insert(push_job)
    end)
  end

  defp maybe_schedule_push(multi, _feed_limit), do: multi
end
