defmodule T.Feeds do
  @moduledoc "Feeds for alternative app. Invites & Calls."

  import Ecto.Query
  import Ecto.Changeset
  import Geo.PostGIS

  require Logger

  alias T.Repo
  alias T.Bot
  alias T.Accounts.{UserReport, GenderPreference}
  alias T.Calls
  alias T.Feeds.{FeedProfile}
  alias T.PushNotifications.DispatchJob

  ### PubSub

  # TODO optimise pubsub:
  # instead of single topic, use `up-to-filter` with each subscriber providing a value up to which
  # they are subscribed, and if the event is below that value -> send it, if not -> don't send it

  @pubsub T.PubSub

  defp notify_subscribers({:error, _multi, _reason, _changes} = fail, _event), do: fail
  defp notify_subscribers({:error, _reason} = fail, _event), do: fail

  defp broadcast(topic, message) do
    Phoenix.PubSub.broadcast(@pubsub, topic, message)
  end

  defp broadcast_from(topic, message) do
    Phoenix.PubSub.broadcast_from(@pubsub, self(), topic, message)
  end

  defp subscribe(topic) do
    Phoenix.PubSub.subscribe(@pubsub, topic)
  end

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

    Matches.Likes
    |> where(user_id: ^user_id)
    |> select([i, p], {p, distance_km(^location, p.location)})
    |> Repo.all()
  end

  ### Feed

  @type feed_cursor :: String.t()
  @type feed_profile :: {%FeedProfile{}, DateTime.t(), distance_km :: non_neg_integer}

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
    profiles_q = filtered_profiles_q(user_id, gender, gender_preferences)

    feed_profiles = profiles_q
      |> limit(^count)
      |> select([s, p], {p, s, distance_km(^location, p.location)})
      |> Repo.all()

    feed_cursor =
      if last = List.last(feed_profiles) do
        {_feed_profile, timestamp, _distance} = last
        timestamp
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

  @spec feed_profiles_q(Ecto.UUID.t(), String.t() | nil) :: Ecto.Query.t()
  defp feed_profiles_q(user_id, nil) do
    Accounts.admin_list_profiles_ordered_by_activity()
    |> order_by([s], asc: s.flake)
    |> where([s], s.user_id != ^user_id)
  end

  defp feed_profiles_q(user_id, last_flake) do
    user_id
    |> feed_profiles_q(nil)
    |> where([s], s.flake > ^last_flake)
  end

  defp reported_user_ids_q(user_id) do
    UserReport |> where(from_user_id: ^user_id) |> select([r], r.on_user_id)
  end

  defp not_hidden_profiles_q do
    where(FeedProfile, hidden?: false)
  end

  defp not_reported_profiles_q(query \\ not_hidden_profiles_q(), user_id) do
    where(query, [p], p.user_id not in subquery(reported_user_ids_q(user_id)))
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
    |> profiles_that_accept_gender_q(gender)
    |> maybe_gender_preferenced_q(gender_preference)
  end
end
