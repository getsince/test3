defmodule T.Feeds do
  @moduledoc "Feeds for the app."

  import Ecto.Query

  alias T.Repo
  alias T.Feeds.{ActiveSession, FeedProfile}

  ### Active Sessions

  @spec activate_session(Ecto.UUID.t(), pos_integer, DateTime.t()) :: %ActiveSession{}
  def activate_session(
        user_id,
        duration_in_minutes \\ 2 * 24 * 60,
        reference \\ DateTime.utc_now()
      ) do
    expires_at = reference |> DateTime.add(60 * duration_in_minutes) |> DateTime.truncate(:second)

    %ActiveSession{user_id: user_id, expires_at: expires_at}
    |> Repo.insert!(on_conflict: {:replace, [:expires_at]}, conflict_target: :user_id)
  end

  @doc false
  @spec deactivate_session(Ecto.UUID.t()) :: boolean
  def deactivate_session(user_id) do
    ActiveSession
    |> where(user_id: ^user_id)
    |> Repo.delete_all()
    |> case do
      {1, nil} -> true
      {0, nil} -> false
    end
  end

  @spec expired_sessions_q(DateTime.t()) :: Ecto.Query.t()
  defp expired_sessions_q(reference) do
    where(ActiveSession, [s], s.expires_at < ^reference)
  end

  @doc false
  def delete_expired_sessions(reference \\ DateTime.utc_now()) do
    reference |> expired_sessions_q() |> Repo.delete_all()
  end

  ### Feed

  @type feed_cursor :: String.t()

  @spec fetch_feed(
          feed_cursor | nil,
          String.t(),
          [String.t()],
          pos_integer,
          # TODO replace with cuckoo filter
          MapSet.t(Ecto.UUID.t())
        ) ::
          {feed_cursor, [%FeedProfile{}]}
  def fetch_feed(cursor, gender, gender_preferences, limit, filter) do
    # decode cursor
    # sort preferences with cursors
    FeedCache.fetch_feed(cursor, gender, gender_preferences, limit, filter)
  end
end
