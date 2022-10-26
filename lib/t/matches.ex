defmodule T.Matches do
  @moduledoc "Likes and matches"

  import Ecto.Query
  import Geo.PostGIS

  require Logger

  alias T.Repo
  alias T.Matches.{Match, MatchEvent, Seen, Interaction}
  alias T.Feeds.FeedProfile

  @type uuid :: Ecto.UUID.t()

  defmacrop distance_km(location1, location2) do
    quote do
      fragment(
        "round(? / 1000)::int",
        st_distance_in_meters(unquote(location1), unquote(location2))
      )
    end
  end

  # - Matches

  @spec list_matches(uuid, Geo.Point.t()) :: [%Match{}]
  def list_matches(user_id, location) do
    matches_with_undying_events_q()
    |> where([match: m], m.user_id_1 == ^user_id or m.user_id_2 == ^user_id)
    |> order_by(desc: :inserted_at)
    |> join(:left, [m], s in Seen, as: :seen, on: s.match_id == m.id and s.user_id == ^user_id)
    |> select([match: m, undying_event: e, seen: s], {m, e.timestamp, s.match_id})
    |> Repo.all()
    |> Enum.map(fn {match, _undying_event_timestamp, seen_match_id} ->
      %Match{
        match
        | expiration_date: nil,
          seen: !!seen_match_id
      }
    end)
    |> preload_match_profiles(user_id, location)
    |> preload_interactions()
  end

  def fetch_mate_id(by_user_id, match_id) do
    match_q = where(Match, id: ^match_id)
    match_q_1 = match_q |> where(user_id_1: ^by_user_id) |> select([m], m.user_id_2)
    match_q_2 = match_q |> where(user_id_2: ^by_user_id) |> select([m], m.user_id_1)
    match_q_1 |> union(^match_q_2) |> Repo.one()
  end

  # TODO cleanup
  defp preload_match_profiles(matches, user_id, location) do
    mate_matches =
      Map.new(matches, fn match ->
        [mate_id] = [match.user_id_1, match.user_id_2] -- [user_id]
        {mate_id, match}
      end)

    mates = Map.keys(mate_matches)

    profiles =
      FeedProfile
      |> where([p], p.user_id in ^mates)
      |> select([p], %{p | distance: distance_km(^location, p.location)})
      |> Repo.all()
      |> Map.new(fn profile -> {profile.user_id, profile} end)

    Enum.map(matches, fn match ->
      [mate_id] = [match.user_id_1, match.user_id_2] -- [user_id]
      %Match{match | profile: Map.fetch!(profiles, mate_id)}
    end)
  end

  defp preload_interactions(matches) do
    match_ids = matches |> Enum.map(fn match -> match.id end)

    interactions =
      Interaction
      |> where([i], i.match_id in ^match_ids)
      |> Repo.all()

    Enum.map(matches, fn match ->
      %Match{match | interactions: Enum.filter(interactions, fn i -> i.match_id == match.id end)}
    end)
  end

  def has_matches(user_id) do
    Match
    |> where([m], m.user_id_1 == ^user_id or m.user_id_2 == ^user_id)
    |> Repo.exists?()
  end

  defp named_match_q do
    from(m in Match, as: :match)
  end

  @undying_events ["call_start", "contact_offer", "contact_click", "interaction_exchange"]

  def matches_with_undying_events_q(query \\ named_match_q()) do
    undying_events_q =
      MatchEvent
      |> where(match_id: parent_as(:match).id)
      |> where([e], e.event in ^@undying_events)
      |> select([e], e.timestamp)
      |> limit(1)

    join(query, :left_lateral, [m], e in subquery(undying_events_q), as: :undying_event)
  end

  def has_undying_events?(match_id) do
    MatchEvent
    |> where(match_id: ^match_id)
    |> where([e], e.event in ^@undying_events)
    |> Repo.exists?()
  end

  def has_interaction?(match_id) do
    Interaction
    |> where(match_id: ^match_id)
    |> limit(1)
    |> Repo.all()
    |> case do
      [] -> nil
      [%Interaction{} = interaction] -> interaction
    end
  end
end
