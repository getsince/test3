defmodule T.Feeds2 do
  @moduledoc "Feeds for alternative app. Invites & Calls."

  import Ecto.Query

  alias T.Repo
  alias T.Accounts.UserReport
  alias T.Invites.CallInvite
  alias T.Feeds.{ActiveSession, FeedProfile}

  ### Active Sessions

  @spec activate_session(Ecto.UUID.t(), integer, DateTime.t()) :: %ActiveSession{}
  def activate_session(user_id, duration_in_minutes, reference \\ DateTime.utc_now()) do
    expires_at = DateTime.add(reference, 60 * duration_in_minutes)
    session = %ActiveSession{user_id: user_id, expires_at: expires_at}
    Repo.insert!(session, on_conflict: :replace_all)
  end

  @spec get_current_session(Ecto.UUID.t()) :: %ActiveSession{} | nil
  def get_current_session(user_id) do
    Repo.get(ActiveSession, user_id)
  end

  @spec expired_sessions_q(DateTime.t()) :: Ecto.Query.t()
  defp expired_sessions_q(reference) do
    where(ActiveSession, [s], s.expires_at < ^reference)
  end

  @spec expired_sessions(DateTime.t()) :: [%ActiveSession{}]
  def expired_sessions(reference \\ DateTime.utc_now()) do
    reference |> expired_sessions_q() |> Repo.all()
  end

  def delete_expired_sessions(reference \\ DateTime.utc_now()) do
    reference |> expired_sessions_q() |> Repo.delete_all()
  end

  ### Invites

  def invite_active_user(_by_user_id, _user_id) do
    # invite and broadcast invite
  end

  def subscribe_for_invites(user_id) do
    Phoenix.PubSub.subscribe(T.PubSub, invites_topic(user_id))
  end

  defp invites_topic(user_id) do
    "__invites:" <> String.downcase(user_id)
  end

  ### Feed

  @type feed_cursor :: DateTime.t()
  @type feed_item :: {%FeedProfile{}, expires_at :: DateTime.t()}

  @spec fetch_feed(Ecto.UUID.t(), pos_integer, feed_cursor | nil) :: {[feed_item], feed_cursor}
  def fetch_feed(user_id, count, feed_cursor) do
    feed_items_with_cursors =
      active_sessions_q(user_id, feed_cursor)
      |> join(:inner, [s], p in subquery(profiles_q(user_id)), on: s.user_id == p.user_id)
      |> limit(^count)
      |> select([s, p], {{p, s.expires_at}, s.inserted_at})
      |> Repo.all()

    feed_cursor =
      if last = List.last(feed_items_with_cursors) do
        {_feed_item, last_session_timestamp} = last
        last_session_timestamp
      end

    feed_items = Enum.map(feed_items_with_cursors, fn {feed_item, _} -> feed_item end)

    {feed_items, feed_cursor}
  end

  @spec get_feed_item(Ecto.UUID.t()) :: feed_item | nil
  def get_feed_item(user_id) do
    p =
      FeedProfile
      |> where(hidden?: false)
      |> where(user_id: ^user_id)

    # TODO filter out reported by current user

    ActiveSession
    |> where(user_id: ^user_id)
    |> join(:inner, [s], p in subquery(p), on: true)
    |> select([s, p], {p, s.expires_at})
    |> Repo.one()
  end

  @spec active_sessions_q(Ecto.UUID.t(), DateTime.t() | nil) :: Ecto.Query.t()
  defp active_sessions_q(user_id, nil) do
    ActiveSession
    |> order_by([s], asc: s.inserted_at)
    |> where([s], s.user_id != ^user_id)
  end

  defp active_sessions_q(user_id, %DateTime{} = last_session_timestamp) do
    user_id
    |> active_sessions_q(nil)
    |> where([s], s.inserted_at > ^last_session_timestamp)
  end

  defp reported_user_ids_q(user_id) do
    UserReport |> where(from_user_id: ^user_id) |> select([r], r.on_user_id)
  end

  defp invited_user_ids(user_id) do
    q1 = CallInvite |> where([i], i.user_id == ^user_id) |> select([i], i.by_user_id)
    q2 = CallInvite |> where([i], i.by_user_id == ^user_id) |> select([i], i.user_id)
    union(q1, ^q2)
  end

  defp profiles_q(user_id) do
    reported_user_ids = reported_user_ids_q(user_id)
    invited_user_ids = invited_user_ids(user_id)

    FeedProfile
    |> where(hidden?: false)
    # TODO is inner join faster?
    |> where([p], p.user_in not in subquery(reported_user_ids))
    # TODO might not need this
    |> where([p], p.user_in not in subquery(invited_user_ids))
  end
end
