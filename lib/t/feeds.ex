defmodule T.Feeds do
  @moduledoc "Feeds for alternative app. Invites & Calls."

  import Ecto.Query
  import Ecto.Changeset
  import Geo.PostGIS

  require Logger

  alias T.Repo
  # alias T.Bot
  # alias T.Accounts
  alias T.Accounts.{UserReport, GenderPreference}
  alias T.Matches.{Match, Like}
  # alias T.Calls
  alias T.Feeds.{FeedProfile, SeenProfile}
  # alias T.PushNotifications.DispatchJob

  ### PubSub

  # TODO optimise pubsub:
  # instead of single topic, use `up-to-filter` with each subscriber providing a value up to which
  # they are subscribed, and if the event is below that value -> send it, if not -> don't send it

  # @pubsub T.PubSub

  # defp notify_subscribers({:error, _multi, _reason, _changes} = fail, _event), do: fail
  # defp notify_subscribers({:error, _reason} = fail, _event), do: fail

  # defp broadcast(topic, message) do
  #   Phoenix.PubSub.broadcast(@pubsub, topic, message)
  # end

  # defp broadcast_from(topic, message) do
  #   Phoenix.PubSub.broadcast_from(@pubsub, self(), topic, message)
  # end

  # defp subscribe(topic) do
  #   Phoenix.PubSub.subscribe(@pubsub, topic)
  # end

  ### Likes

  defmacrop distance_km(location1, location2) do
    quote do
      fragment(
        "round(? / 1000)::int",
        st_distance_in_meters(unquote(location1), unquote(location2))
      )
    end
  end

  # TODO accept cursor
  @spec list_received_likes(Ecto.UUID.t(), Geo.Point.t()) :: [feed_profile]
  def list_received_likes(user_id, location) do
    profiles_q = not_reported_profiles_q(user_id)

    Like
    |> where(user_id: ^user_id)
    |> where([l], is_nil(l.declined))
    |> not_match1_profiles_q(user_id)
    |> not_match2_profiles_q(user_id)
    |> order_by(desc: :inserted_at)
    |> join(:inner, [l], p in subquery(profiles_q), on: p.user_id == l.by_user_id)
    |> select([l, p], {p, distance_km(^location, p.location)})
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

  ### Feed

  @type feed_cursor :: DateTime.t()
  @type feed_profile :: {%FeedProfile{}, distance_km :: non_neg_integer}

  @spec fetch_feed(
          Ecto.UUID.t(),
          Geo.Point.t(),
          String.t(),
          [String.t()],
          pos_integer,
          feed_cursor | nil
        ) ::
          {[feed_profile], feed_cursor}
  def fetch_feed(user_id, location, gender, gender_preferences, count, feed_cursor) do
    feed_profiles =
      feed_profiles_q(user_id, gender, gender_preferences, feed_cursor)
      |> limit(^count)
      |> select([p], {p, distance_km(^location, p.location)})
      |> Repo.all()

    feed_cursor =
      if last = List.last(feed_profiles) do
        {feed_profile, _distance} = last
        feed_profile.last_active
      else
        feed_cursor
      end

    {feed_profiles, feed_cursor}
  end

  @spec get_mate_feed_profile(Ecto.UUID.t()) :: %FeedProfile{} | nil
  def get_mate_feed_profile(user_id) do
    FeedProfile
    |> where(user_id: ^user_id)
    |> Repo.one()
  end

  defp feed_profiles_q(user_id, gender, gender_preference, nil) do
    treshold_date = DateTime.utc_now() |> DateTime.add(-30 * 24 * 60 * 60, :second)

    filtered_profiles_q(user_id, gender, gender_preference)
    |> where([p], p.user_id != ^user_id)
    |> where([p], p.last_active > ^treshold_date)
    |> order_by(desc: :last_active)
  end

  defp feed_profiles_q(user_id, gender, gender_preference, last_date) do
    feed_profiles_q(user_id, gender, gender_preference, nil)
    |> where([p], p.last_active < ^last_date)
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
    |> profiles_that_accept_gender_q(gender)
    |> maybe_gender_preferenced_q(gender_preference)
  end

  @doc "mark_profile_seen(user_id, by: <user-id>)"
  def mark_profile_seen(user_id, opts) do
    by_user_id = Keyword.fetch!(opts, :by)

    seen_changeset(by_user_id, user_id)
    |> Repo.insert()
  end

  defp seen_changeset(by_user_id, user_id) do
    %SeenProfile{by_user_id: by_user_id, user_id: user_id}
    |> change()
    |> unique_constraint(:seen, name: :seen_profiles_pkey)
  end

  def prune_seen_profiles(ttl_days) do
    SeenProfile
    |> where([s], s.inserted_at < fragment("now() - ? * interval '1 day'", ^ttl_days))
    |> Repo.delete_all()
  end
end
