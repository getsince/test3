defmodule T.Feeds do
  @moduledoc "Profile feeds for the app."

  import Ecto.{Query, Changeset}
  alias Ecto.Multi
  import Geo.PostGIS

  require Logger

  import T.Cluster, only: [primary_rpc: 3]

  alias T.Repo

  alias T.Accounts.{Profile, UserReport, GenderPreference}
  alias T.Matches.{Match, Like}

  alias T.Feeds.{
    FeedProfile,
    SeenProfile,
    FeededProfile,
    FeedFilter,
    CalculatedFeed
  }

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
  @feed_limit_period 12 * 60 * 60
  @feed_profiles_recency_limit 90 * 24 * 60 * 60
  @quality_likes_count_treshold 50

  @onboarding_feed_count 50
  @onboarding_categories_stickers %{
    "искусство" => "creatives",
    "art" => "creatives",
    "фотография" => "creatives",
    "photography" => "creatives",
    "SMM" => "creatives",
    "musician" => "creatives",
    "музыкант" => "creatives",
    "общение" => "communication",
    "communication" => "communication",
    "бег" => "sports",
    "running" => "sports",
    "dancing" => "sports",
    "танцы" => "sports",
    "кроссфит" => "sports",
    "crossfit" => "sports",
    "digital" => "tech",
    "Яндекс" => "tech",
    "Yandex" => "tech",
    "science" => "tech",
    "наука" => "tech",
    "нетворкинг" => "networking",
    "networking" => "networking",
    "психология" => "mindfulness",
    "psychology" => "mindfulness",
    "саморазвитие" => "mindfulness",
    "медитация" => "mindfulness",
    "meditation" => "mindfulness",
    "йога" => "mindfulness",
    "yoga" => "mindfulness",
    "психолог" => "mindfulness"
  }

  def feed_fetch_count, do: @feed_fetch_count
  def feed_limit_period, do: @feed_limit_period
  def quality_likes_count_treshold, do: @quality_likes_count_treshold

  # TODO refactor
  @spec fetch_feed(
          Ecto.UUID.t(),
          Geo.Point.t(),
          String.t(),
          %FeedFilter{},
          String.t() | nil
        ) :: [%FeedProfile{}] | {DateTime.t(), map}
  # TODO remove writes
  def fetch_feed(user_id, location, gender, feed_filter, first_fetch) do
    %FeedFilter{genders: gender_preference} = feed_filter

    cond do
      first_fetch and
          length(
            previously_feeded_profiles(
              user_id,
              location,
              gender,
              gender_preference,
              @feed_fetch_count
            )
          ) > 0 ->
        previously_feeded_profiles(
          user_id,
          location,
          gender,
          gender_preference,
          @feed_fetch_count
        )

      true ->
        cond do
          first_time_user(user_id) ->
            first_time_user_feed(user_id, location, gender, feed_filter, @feed_fetch_count)

          true ->
            continue_feed(user_id, location, gender, feed_filter, @feed_fetch_count)
        end
    end
  end

  defp previously_feeded_profiles(user_id, location, gender, gender_preference, count) do
    FeededProfile
    |> where(for_user_id: ^user_id)
    |> join(:inner, [f], p in FeedProfile, on: f.user_id == p.user_id)
    |> where(
      [f, p],
      p.user_id in subquery(filtered_profiles_ids_q(user_id, gender, gender_preference))
    )
    |> limit(^count)
    |> select([f, p], %{p | distance: distance_km(^location, p.location)})
    |> Repo.all()
  end

  defp first_time_user(user_id) do
    SeenProfile |> where(by_user_id: ^user_id) |> Repo.all() |> length() == 0 and
      CalculatedFeed |> where(for_user_id: ^user_id) |> Repo.all() |> length() == 0
  end

  defp first_time_user_feed(user_id, location, gender, feed_filter, count) do
    %FeedFilter{
      genders: gender_preference,
      min_age: min_age,
      max_age: max_age,
      distance: distance
    } = feed_filter

    feed =
      filtered_profiles_q(user_id, gender, gender_preference)
      |> where([p], p.times_liked >= ^@quality_likes_count_treshold)
      |> where([p], fragment("jsonb_array_length(?) > 2", p.story))
      |> order_by(fragment("location <-> ?::geometry", ^location))
      |> maybe_apply_age_filters(min_age, max_age)
      |> maybe_apply_distance_filter(location, distance)
      |> limit(^count)
      |> select([p], %{p | distance: distance_km(^location, p.location)})
      |> Repo.all()

    mark_profiles_feeded(user_id, feed)
    feed
  end

  defp continue_feed(user_id, location, gender, feed_filter, count) do
    %FeedFilter{genders: gender_preference} = feed_filter

    feeded_ids_q = FeededProfile |> where(for_user_id: ^user_id) |> select([f], f.user_id)

    calculated_feed_ids =
      CalculatedFeed
      |> where(for_user_id: ^user_id)
      |> where([p], p.user_id not in subquery(feeded_ids_q))
      |> where(
        [p],
        p.user_id in subquery(filtered_profiles_ids_q(user_id, gender, gender_preference))
      )
      |> select([p], p.user_id)
      |> Repo.all()

    calculated_feed =
      preload_feed_profiles(
        calculated_feed_ids,
        user_id,
        location,
        gender,
        feed_filter,
        count
      )

    default_feed =
      if length(calculated_feed) < count do
        default_feed(
          user_id,
          calculated_feed_ids,
          feeded_ids_q,
          location,
          gender,
          feed_filter,
          count - length(calculated_feed)
        )
      else
        []
      end

    feed = calculated_feed ++ default_feed

    mark_profiles_feeded(user_id, feed)
    feed
  end

  defp preload_feed_profiles(profile_ids, user_id, location, gender, feed_filter, count) do
    %FeedFilter{
      genders: gender_preference,
      min_age: min_age,
      max_age: max_age,
      distance: distance
    } = feed_filter

    feed_profiles_q(user_id, gender, gender_preference)
    |> where([p], p.user_id in ^profile_ids)
    |> maybe_apply_age_filters(min_age, max_age)
    |> maybe_apply_distance_filter(location, distance)
    |> limit(^count)
    |> select([p], %{p | distance: distance_km(^location, p.location)})
    |> Repo.all()
  end

  defp default_feed(
         user_id,
         calculated_feed_ids,
         feeded_ids_q,
         location,
         gender,
         feed_filter,
         count
       ) do
    %FeedFilter{
      genders: gender_preference,
      min_age: min_age,
      max_age: max_age,
      distance: distance
    } = feed_filter

    feed_profiles_q(user_id, gender, gender_preference)
    |> where([p], p.user_id not in ^calculated_feed_ids)
    |> where([p], p.user_id not in subquery(feeded_ids_q))
    |> order_by(fragment("location <-> ?::geometry", ^location))
    |> maybe_apply_age_filters(min_age, max_age)
    |> maybe_apply_distance_filter(location, distance)
    |> limit(^count)
    |> select([p], %{p | distance: distance_km(^location, p.location)})
    |> Repo.all()
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

  def empty_feeded_profiles(user_id) do
    primary_rpc(__MODULE__, :local_empty_feeded_profiles, [user_id])
  end

  @doc false
  def local_empty_feeded_profiles(user_id) do
    FeededProfile |> where(for_user_id: ^user_id) |> Repo.delete_all()
  end

  def get_feed_filter(user_id) do
    genders = T.Accounts.list_gender_preference(user_id)

    {min_age, max_age, distance} =
      Profile
      |> where(user_id: ^user_id)
      |> select([p], {p.min_age, p.max_age, p.distance})
      |> Repo.one!()

    %FeedFilter{genders: genders, min_age: min_age, max_age: max_age, distance: distance}
  end

  @spec get_mate_feed_profile(Ecto.UUID.t(), Geo.Point.t()) :: %FeedProfile{} | nil
  def get_mate_feed_profile(user_id, location) do
    not_hidden_profiles_q()
    |> where(user_id: ^user_id)
    |> select([p], %{p | distance: distance_km(^location, p.location)})
    |> Repo.one()
  end

  defp feed_profiles_q(user_id, gender, gender_preference) do
    treshold_date = DateTime.utc_now() |> DateTime.add(-@feed_profiles_recency_limit, :second)

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

  defp filtered_profiles_q(user_id, gender, gender_preference) do
    not_hidden_profiles_q()
    |> not_reported_profiles_q(user_id)
    |> not_liked_profiles_q(user_id)
    |> not_liker_profiles_q(user_id)
    |> not_seen_profiles_q(user_id)
    |> profiles_that_accept_gender_q(gender)
    |> maybe_gender_preferenced_q(gender_preference)
  end

  defp filtered_profiles_ids_q(user_id, gender, gender_preference) do
    filtered_profiles_q(user_id, gender, gender_preference) |> select([p], p.user_id)
  end

  ### Onboarding Feed

  def fetch_onboarding_feed(remote_ip, likes_count_treshold \\ @quality_likes_count_treshold) do
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

    stickers = @onboarding_categories_stickers |> Map.keys()

    user_ids = user_ids_with_stickers(stickers)

    profiles =
      fetch_onboarding_profiles(user_ids, location, likes_count_treshold, @onboarding_feed_count)

    profiles
    |> Enum.map(fn profile -> %{profile: profile, categories: profile_categories(profile)} end)
  end

  defp profile_categories(%FeedProfile{story: story}) do
    story
    |> Enum.map(fn p -> p["labels"] end)
    |> List.flatten()
    |> Enum.reduce([], fn label, categories ->
      case @onboarding_categories_stickers[label["answer"]] do
        nil -> categories
        category -> [category | categories]
      end
    end)
  end

  def user_ids_with_stickers(stickers) do
    joined_stickers = Enum.join(stickers, "', '")

    %Postgrex.Result{columns: ["user_id"], rows: rows} =
      Repo.query!("""
      SELECT DISTINCT user_id
      FROM (SELECT user_id, jsonb_array_elements(jsonb_array_elements(story) -> 'labels') AS label FROM profiles
      WHERE jsonb_array_length(story) > 2) AS l
      WHERE (l.label ->> 'answer') = ANY (ARRAY ['#{joined_stickers}'])
      """)

    Enum.map(rows, fn [user_id] -> Ecto.UUID.cast!(user_id) end)
  end

  defp fetch_onboarding_profiles(user_ids, location, likes_count_treshold, count) do
    not_hidden_profiles_q()
    |> where([p], p.user_id in ^user_ids)
    |> where([p], p.times_liked >= ^likes_count_treshold)
    |> order_by(fragment("location <-> ?::geometry", ^location))
    |> limit(^count)
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
    |> foreign_key_constraint(:fkey, name: :user_id)
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
end
