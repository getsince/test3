defmodule T.Feeds2 do
  @moduledoc "Feeds for alternative app. Invites & Calls."

  import Ecto.Query

  alias T.Repo
  alias T.Accounts.{Profile, UserReport}
  alias T.Invites.CallInvite
  alias T.Feeds.ActiveSession

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

  ### Feed

  defmodule Cursor do
    @moduledoc false
    defstruct [:next_sessions, :last_session_timestamp, :user_id]

    @type t :: %__MODULE__{
            next_sessions: [%ActiveSession{}],
            last_session_timestamp: DateTime.t() | nil,
            user_id: Ecto.UUID.t()
          }
  end

  @spec init_feed(Ecto.UUID.t()) :: Cursor.t()
  def init_feed(user_id) do
    refill_feed(%Cursor{user_id: user_id, next_sessions: []})
  end

  @spec active_sessions_q(Ecto.UUID.t(), DateTime.t() | nil) :: Ecto.Query.t()
  defp active_sessions_q(user_id, nil) do
    ActiveSession
    |> order_by([s], desc: s.inserted_at)
    |> where([s], s.user_id != ^user_id)
  end

  defp active_sessions_q(user_id, %DateTime{} = last_session_timestamp) do
    user_id
    |> active_sessions_q(nil)
    |> where([s], s.inserted_at > ^last_session_timestamp)
  end

  @spec refill_feed(Cursor.t()) :: Cursor.t()
  def refill_feed(%Cursor{next_sessions: []} = cursor) do
    %Cursor{user_id: user_id, last_session_timestamp: last_session_timestamp} = cursor

    sessions =
      user_id
      |> active_sessions_q(last_session_timestamp)
      |> Repo.all()

    last_session_timestamp =
      if latest_session = List.first(sessions) do
        DateTime.from_naive!(latest_session.inserted_at, "Etc/UTC")
      else
        last_session_timestamp
      end

    %Cursor{
      next_sessions: sessions,
      last_session_timestamp: last_session_timestamp,
      user_id: user_id
    }
  end

  @type feed_item :: {%Profile{}, expires_at :: DateTime.t()}

  @spec consume_feed(Cursor.t(), pos_integer, DateTime.t()) :: {[feed_item], Cursor.t()}
  def consume_feed(cursor, count, reference \\ DateTime.utc_now()) when count > 0 do
    %Cursor{next_sessions: sessions, user_id: user_id} = cursor
    {to_fetch, next_sessions} = sessions |> actually_active(reference) |> Enum.split(count)
    {fetch_feed_items(to_fetch, user_id), %Cursor{cursor | next_sessions: next_sessions}}
  end

  @spec actually_active([%ActiveSession{}], DateTime.t()) :: [%ActiveSession{}]
  defp actually_active(sessions, reference) do
    Enum.filter(sessions, fn %ActiveSession{expires_at: expires_at} ->
      DateTime.compare(reference, expires_at) == :lt
    end)
  end

  defp reported_user_ids_q(user_id) do
    UserReport |> where(from_user_id: ^user_id) |> select([r], r.on_user_id)
  end

  defp invited_user_ids(user_id) do
    q1 = CallInvite |> where([i], i.user_id == ^user_id) |> select([i], i.by_user_id)
    q2 = CallInvite |> where([i], i.by_user_id == ^user_id) |> select([i], i.user_id)
    union(q1, ^q2)
  end

  @spec fetch_feed_items([%ActiveSession{}], Ecto.UUID.t()) :: [feed_item]
  defp fetch_feed_items(active_sessions, user_id) do
    reported_user_ids = reported_user_ids_q(user_id)
    invited_user_ids = invited_user_ids(user_id)

    profiles_lookup =
      Profile
      |> where([p], p.user_id in ^Enum.map(active_sessions, & &1.user_id))
      |> where(hidden?: false)
      # TODO is inner join faster?
      |> where([p], p.user_in not in subquery(reported_user_ids))
      # TODO might not need this
      |> where([p], p.user_in not in subquery(invited_user_ids))
      |> Repo.all()
      |> Map.new(fn profile -> {profile.user_id, profile} end)

    Enum.reduce(active_sessions, [], fn session, acc ->
      %ActiveSession{user_id: user_id, expires_at: expires_at} = session

      if profile = profiles_lookup[user_id] do
        [{profile, expires_at} | acc]
      else
        acc
      end
    end)
  end
end
