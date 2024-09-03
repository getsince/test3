defmodule Since.Feeds do
  @moduledoc "Profile feeds for the app."

  import Ecto.{Query, Changeset}
  alias Ecto.Multi
  import Geo.PostGIS

  require Logger

  alias Since.{Repo, Bot}

  alias Since.Accounts.{Profile, UserReport, GenderPreference}
  alias Since.Chats.Chat
  alias Since.Games.Compliment

  alias Since.Feeds.{
    FeedProfile,
    SeenProfile,
    FeededProfile,
    FeedFilter,
    CalculatedFeed,
    Meeting
  }

  ### PubSub

  # TODO optimise pubsub:
  # instead of single topic, use `up-to-filter` with each subscriber providing a value up to which
  # they are subscribed, and if the event is below that value -> send it, if not -> don't send it

  @pubsub Since.PubSub
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
  # TODO bring back
  @feed_profiles_recency_limit 180 * 24 * 60 * 60
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

  @feed_categories [
    "recommended",
    "new",
    "recent",
    "close",
    "creatives",
    "communication",
    "sports",
    "tech",
    "networking",
    "mindfulness"
  ]

  def feed_fetch_count, do: @feed_fetch_count
  def feed_limit_period, do: @feed_limit_period
  def quality_likes_count_treshold, do: @quality_likes_count_treshold
  def feed_categories, do: @feed_categories

  def fetch_feed(
        user_id,
        location,
        gender,
        feed_filter,
        first_fetch,
        feed_category \\ "recommended"
      ) do
    if first_fetch, do: empty_feeded_profiles(user_id)

    feeded_ids_q = FeededProfile |> where(for_user_id: ^user_id) |> select([f], f.user_id)

    feed =
      case feed_category do
        "recommended" ->
          fetch_recommended_feed(user_id, location, gender, feeded_ids_q, feed_filter)

        _ ->
          fetch_category_feed(user_id, location, gender, feed_category, feeded_ids_q, feed_filter)
      end

    mark_profiles_feeded(user_id, feed)
    feed
  end

  defp fetch_recommended_feed(user_id, location, gender, feeded_ids_q, feed_filter) do
    cond do
      first_time_user(user_id) ->
        first_time_user_feed(user_id, location, gender, feed_filter, @feed_fetch_count)

      true ->
        calculated_feed_ids =
          CalculatedFeed
          |> where(for_user_id: ^user_id)
          |> where([p], p.user_id not in subquery(feeded_ids_q))
          |> where(
            [p],
            p.user_id in subquery(feed_profiles_ids_q(user_id, gender, feed_filter.genders))
          )
          |> select([p], p.user_id)
          |> Repo.all()

        calculated_feed =
          preload_feed_profiles(
            calculated_feed_ids,
            user_id,
            location,
            gender,
            feed_filter
          )

        default_feed =
          if length(calculated_feed) < @feed_fetch_count do
            default_feed(
              user_id,
              calculated_feed_ids,
              feeded_ids_q,
              location,
              gender,
              feed_filter,
              @feed_fetch_count - length(calculated_feed)
            )
          else
            []
          end

        calculated_feed ++ default_feed
    end
  end

  defp first_time_user(user_id) do
    SeenProfile |> where(by_user_id: ^user_id) |> Repo.all() |> length() == 0 and
      CalculatedFeed |> where(for_user_id: ^user_id) |> Repo.all() |> length() == 0
  end

  defp first_time_user_feed(user_id, location, gender, feed_filter, count) do
    feed_profiles_q(user_id, gender, feed_filter.genders)
    |> where([p], p.times_liked >= ^@quality_likes_count_treshold)
    |> where([p], fragment("jsonb_array_length(?) > 2", p.story))
    |> order_by(fragment("location <-> ?::geometry", ^location))
    |> maybe_apply_age_filters(feed_filter)
    |> maybe_apply_distance_filter(location, feed_filter.distance)
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
    feed_profiles_q(user_id, gender, feed_filter.genders)
    |> where([p], p.user_id not in ^calculated_feed_ids)
    |> where([p], p.user_id not in subquery(feeded_ids_q))
    |> not_seen_profiles_q(user_id)
    |> order_by(fragment("location <-> ?::geometry", ^location))
    |> maybe_apply_age_filters(feed_filter)
    |> maybe_apply_distance_filter(location, feed_filter.distance)
    |> limit(^count)
    |> select([p], %{p | distance: distance_km(^location, p.location)})
    |> Repo.all()
  end

  defp preload_feed_profiles(profile_ids, user_id, location, gender, feed_filter) do
    feed_profiles_q(user_id, gender, feed_filter.genders)
    |> where([p], p.user_id in ^profile_ids)
    |> maybe_apply_age_filters(feed_filter)
    |> maybe_apply_distance_filter(location, feed_filter.distance)
    |> limit(^@feed_fetch_count)
    |> select([p], %{p | distance: distance_km(^location, p.location)})
    |> Repo.all()
  end

  defp seen_user_ids_q(user_id) do
    SeenProfile |> where(by_user_id: ^user_id) |> select([s], s.user_id)
  end

  defp not_seen_profiles_q(query, user_id) do
    where(query, [p], p.user_id not in subquery(seen_user_ids_q(user_id)))
  end

  defp fetch_category_feed(
         user_id,
         location,
         gender,
         feed_category,
         feeded_ids_q,
         feed_filter
       ) do
    feed_profiles_q(user_id, gender, feed_filter.genders)
    |> where([p], p.user_id not in subquery(feeded_ids_q))
    |> join(:left, [p, g], s in SeenProfile, on: [user_id: p.user_id, by_user_id: ^user_id])
    |> maybe_filter_by_sticker(feed_category)
    |> order_by_feed_category(feed_category, location)
    |> maybe_apply_age_filters(feed_filter)
    |> maybe_apply_distance_filter(location, feed_filter.distance)
    |> limit(^@feed_fetch_count)
    |> select([p, g, s], %{p | distance: distance_km(^location, p.location)})
    |> Repo.all()
  end

  defp maybe_filter_by_sticker(query, feed_category)
       when feed_category in ["recommended", "new", "recent", "close"],
       do: query

  defp maybe_filter_by_sticker(query, feed_category) do
    category_stickers =
      @onboarding_categories_stickers
      |> Map.filter(fn {_key, value} -> value == feed_category end)
      |> Map.keys()

    query |> where(fragment("stickers && ?", ^category_stickers))
  end

  defp order_by_feed_category(query, "new", _location) do
    query |> order_by(desc: :user_id)
  end

  defp order_by_feed_category(query, "recent", _location) do
    query |> order_by(desc: :last_active)
  end

  defp order_by_feed_category(query, "close", location) do
    query |> order_by(fragment("location <-> ?::geometry", ^location))
  end

  defp order_by_feed_category(query, _feed_category, location) do
    query
    |> order_by([p, g, s], [
      fragment("? IS NOT NULL", s.by_user_id),
      fragment("location <-> ?::geometry", ^location)
    ])
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

  defp mark_profiles_feeded(for_user_id, feed_profiles) do
    feeded_user_ids = Enum.map(feed_profiles, fn profile -> profile.user_id end)
    inserted_at = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_naive()

    data =
      Enum.map(feeded_user_ids, fn feeded_user_id ->
        %{for_user_id: for_user_id, user_id: feeded_user_id, inserted_at: inserted_at}
      end)

    Repo.insert_all(FeededProfile, data, on_conflict: :nothing)
  end

  def empty_feeded_profiles(user_id) do
    FeededProfile |> where(for_user_id: ^user_id) |> Repo.delete_all()
  end

  def get_feed_filter(user_id) do
    genders = Since.Accounts.list_gender_preference(user_id)

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

  defp feed_profiles_ids_q(user_id, gender, gender_preference) do
    feed_profiles_q(user_id, gender, gender_preference) |> select([p], p.user_id)
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

  defp chatter_user_ids_q(user_id) do
    binary_uuid = Ecto.Bigflake.UUID.dump!(user_id)

    Chat
    |> where([c], c.user_id_1 == ^user_id or c.user_id_2 == ^user_id)
    |> select(
      fragment(
        "CASE WHEN user_id_1 = ?::uuid THEN user_id_2 ELSE user_id_1 END",
        ^binary_uuid
      )
    )
  end

  defp not_chatters_profiles_q(query, user_id) do
    where(query, [p], p.user_id not in subquery(chatter_user_ids_q(user_id)))
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

  defp filtered_profiles_q(user_id, gender, gender_preference) do
    not_hidden_profiles_q()
    |> not_reported_profiles_q(user_id)
    |> not_reporter_profiles_q(user_id)
    |> not_chatters_profiles_q(user_id)
    |> profiles_that_accept_gender_q(gender)
    |> maybe_gender_preferenced_q(gender_preference)
    |> not_complimented_profiles_q(user_id)
  end

  ### Onboarding Feed

  def fetch_onboarding_feed(remote_ip, likes_count_treshold \\ @quality_likes_count_treshold) do
    location =
      case remote_ip do
        nil ->
          nil

        _ ->
          case Since.Location.location_from_ip(remote_ip) do
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

  @doc "mark_profile_seen(user_id, by: <user-id>)"
  def mark_profile_seen(user_id, opts) do
    by_user_id = Keyword.fetch!(opts, :by)

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

  ### Meetings

  def fetch_meetings(user_id, location, cursor) do
    Meeting
    |> maybe_apply_cursor(cursor)
    |> join(:inner, [m], p in FeedProfile, on: p.user_id == m.user_id)
    |> where([m, p], p.hidden? == false)
    |> where([m, p], p.user_id not in subquery(reported_user_ids_q(user_id)))
    |> where([m, p], p.user_id not in subquery(reporter_user_ids_q(user_id)))
    |> order_by([m], desc: m.id)
    |> limit(^@feed_fetch_count)
    |> select([m, p], %{m | profile: %{p | distance: distance_km(^location, p.location)}})
    |> Repo.all()
  end

  defp maybe_apply_cursor(query, cursor) do
    if cursor do
      query |> where([m], m.id < ^cursor)
    else
      query
    end
  end

  def save_meeting(user_id, meeting_data) do
    m = "new meeting #{meeting_data["text"]} from #{user_id}"
    Logger.warning(m)
    Bot.async_post_message(m)

    Multi.new()
    |> Multi.insert(:meeting, meeting_changeset(%{data: meeting_data, user_id: user_id}))
    |> Repo.transaction()
    |> case do
      {:ok, %{meeting: %Meeting{} = meeting}} ->
        {:ok, meeting}

      {:error, :meeting, %Ecto.Changeset{} = changeset, _changes} ->
        {:error, changeset}
    end
  end

  defp meeting_changeset(attrs) do
    %Meeting{}
    |> cast(attrs, [:data, :user_id])
    |> validate_required([:data, :user_id])
    |> validate_change(:data, fn :data, meeting_data ->
      case meeting_data do
        %{"text" => _text, "background" => background} ->
          case background do
            %{"color" => _color} -> []
            %{"gradient" => [_color1, _color2]} -> []
            false -> [meeting: "unsupported meeting type"]
          end

        nil ->
          [meeting: "unrecognized meeting type"]

        _ ->
          [meeting: "unrecognized meeting type"]
      end
    end)
  end

  def delete_meeting(user_id, meeting_id) do
    m = "meeting #{meeting_id} deleted by user #{user_id}"
    Logger.warning(m)
    Bot.async_post_message(m)

    Multi.new()
    |> Multi.run(:delete_meeting, fn _repo, _changes ->
      Meeting
      |> where([m], m.id == ^meeting_id)
      |> where([m], m.user_id == ^user_id)
      |> Repo.delete_all()
      |> case do
        {1, _} -> {:ok, meeting_id}
        {0, _} -> {:error, :meeting_not_found}
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, _} -> :ok
      {:error, :delete_meeting, _error, _changes} -> :error
    end
  end
end
