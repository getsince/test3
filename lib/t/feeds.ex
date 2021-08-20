defmodule T.Feeds do
  @moduledoc "Feeds for alternative app. Invites & Calls."

  import Ecto.Query
  import Ecto.Changeset

  alias T.{Repo, Bot}
  alias T.Accounts.UserReport
  alias T.Invites.CallInvite
  alias T.Feeds.{ActiveSession, FeedProfile}
  alias T.PushNotifications.DispatchJob

  ### PubSub

  # TODO optimise pubsub:
  # instead of single topic, use `up-to-filter` with each subscriber providing a value up to which
  # they are subscribed, and if the event is below that value -> send it, if not -> don't send it

  @pubsub T.PubSub

  defp notify_subscribers({:ok, %{invite: invite}} = success, :invited = event) do
    %CallInvite{by_user_id: by_user_id, user_id: user_id} = invite
    topic = invites_topic(user_id)
    broadcast(topic, {__MODULE__, event, by_user_id})
    success
  end

  defp notify_subscribers(%ActiveSession{user_id: user_id} = session, :activated = event) do
    broadcast(activated_topic(), {__MODULE__, event, user_id})
    session
  end

  defp notify_subscribers({:error, _multi, _reason, _changes} = fail, _event), do: fail
  defp notify_subscribers({:error, _reason} = fail, _event), do: fail

  defp notify_deactivated(user_id) when is_binary(user_id) do
    broadcast(deactivated_topic(), {__MODULE__, :deactivated, user_id})
  end

  defp notify_deactivated(user_ids) when is_list(user_ids) do
    topic = deactivated_topic()

    for user_id <- user_ids do
      broadcast(topic, {__MODULE__, :deactivated, user_id})
    end
  end

  def subscribe_for_invites(user_id) do
    subscribe(invites_topic(user_id))
  end

  def subscribe_for_activated_sessions do
    subscribe(activated_topic())
  end

  def subscribe_for_deactivated_sessions do
    subscribe(deactivated_topic())
  end

  defp broadcast(topic, message) do
    Phoenix.PubSub.broadcast(@pubsub, topic, message)
  end

  defp subscribe(topic) do
    Phoenix.PubSub.subscribe(@pubsub, topic)
  end

  defp invites_topic(user_id) do
    "__invites:" <> String.downcase(user_id)
  end

  defp deactivated_topic, do: "__deact:"
  defp activated_topic, do: "__act:"

  ### Active Sessions

  # TODO test pubsub
  @spec activate_session(Ecto.UUID.t(), integer, DateTime.t()) :: %ActiveSession{}
  def activate_session(user_id, duration_in_minutes, reference \\ DateTime.utc_now()) do
    Bot.async_post_silent_message(
      "user #{user_id} activated session for #{duration_in_minutes} minutes since #{reference}"
    )

    expires_at = reference |> DateTime.add(60 * duration_in_minutes) |> DateTime.truncate(:second)

    %ActiveSession{user_id: user_id, expires_at: expires_at}
    |> Repo.insert!(on_conflict: :replace_all, conflict_target: :user_id)
    |> notify_subscribers(:activated)
  end

  # TODO test pubsub
  @spec deactivate_session(Ecto.UUID.t()) :: boolean
  def deactivate_session(user_id) do
    ActiveSession
    |> where(user_id: ^user_id)
    |> Repo.delete_all()
    |> case do
      {1, nil} ->
        notify_deactivated(user_id)
        true

      {0, nil} ->
        false
    end
  end

  @spec get_current_session(Ecto.UUID.t()) :: %ActiveSession{} | nil
  def get_current_session(user_id) do
    ActiveSession
    |> where(user_id: ^user_id)
    |> Repo.one()
  end

  @spec expired_sessions_q(DateTime.t()) :: Ecto.Query.t()
  defp expired_sessions_q(reference) do
    where(ActiveSession, [s], s.expires_at < ^reference)
  end

  @spec expired_sessions(DateTime.t()) :: [%ActiveSession{}]
  def expired_sessions(reference \\ DateTime.utc_now()) do
    reference |> expired_sessions_q() |> Repo.all()
  end

  # TODO test pubsub
  def delete_expired_sessions(reference \\ DateTime.utc_now()) do
    {_count, user_ids} =
      result =
      reference
      |> expired_sessions_q()
      |> select([s], s.user_id)
      |> Repo.delete_all()

    notify_deactivated(user_ids)
    result
  end

  ### Invites

  @spec invite_active_user(Ecto.UUID.t(), Ecto.UUID.t()) :: boolean
  def invite_active_user(by_user_id, user_id) do
    Bot.async_post_silent_message("user #{by_user_id} invited #{user_id}")

    Ecto.Multi.new()
    |> mark_invited(by_user_id, user_id)
    |> schedule_invite_push_notification(by_user_id, user_id)
    |> Repo.transaction()
    |> notify_subscribers(:invited)
    |> case do
      {:ok, _changes} -> true
      {:error, :invite, _changeset, _changes} -> false
    end
  end

  # TODO accept cursor
  @spec list_received_invites(Ecto.UUID.t()) :: [feed_item]
  def list_received_invites(user_id) do
    profiles_q = not_reported_profiles_q(user_id)

    CallInvite
    |> where(user_id: ^user_id)
    |> join(:inner, [i], s in ActiveSession, on: i.by_user_id == s.user_id)
    |> join(:inner, [..., s], p in subquery(profiles_q), on: p.user_id == s.user_id)
    |> select([i, s, p], {p, s})
    |> Repo.all()
  end

  defp mark_invited(multi, by_user_id, user_id, inserted_at \\ NaiveDateTime.utc_now()) do
    invite = %CallInvite{
      by_user_id: by_user_id,
      user_id: user_id,
      inserted_at: NaiveDateTime.truncate(inserted_at, :second)
    }

    changeset =
      invite
      |> change()
      |> unique_constraint(:duplicate, name: "call_invites_pkey")
      |> foreign_key_constraint(:by_user_id)
      |> foreign_key_constraint(:user_id)

    Ecto.Multi.insert(multi, :invite, changeset)
  end

  defp schedule_invite_push_notification(multi, by_user_id, user_id) do
    job = DispatchJob.new(%{"type" => "invite", "by_user_id" => by_user_id, "user_id" => user_id})
    Oban.insert(multi, :invite_push_notification, job)
  end

  def delete_invites_for_blocked(blocked_user_id) do
    CallInvite
    |> where(by_user_id: ^blocked_user_id)
    |> or_where(user_id: ^blocked_user_id)
    |> Repo.delete_all()
  end

  def delete_invites_for_reported(reporter_id, reported_id) do
    CallInvite
    |> where([i], i.by_user_id == ^reporter_id and i.user_id == ^reported_id)
    |> or_where([i], i.user_id == ^reporter_id and i.by_user_id == ^reported_id)
    |> Repo.delete_all()
  end

  ### Feed

  @type feed_cursor :: String.t()
  @type feed_item :: {%FeedProfile{}, %ActiveSession{}}

  @spec fetch_feed(Ecto.UUID.t(), pos_integer, feed_cursor | nil) :: {[feed_item], feed_cursor}
  def fetch_feed(user_id, count, feed_cursor) do
    profiles_q = not_invited_profiles_q(user_id)

    feed_items =
      active_sessions_q(user_id, feed_cursor)
      |> join(:inner, [s], p in subquery(profiles_q), on: s.user_id == p.user_id)
      |> limit(^count)
      |> select([s, p], {p, s})
      |> Repo.all()

    feed_cursor =
      if last = List.last(feed_items) do
        {_feed_profile, %ActiveSession{flake: last_flake}} = last
        last_flake
      else
        feed_cursor
      end

    {feed_items, feed_cursor}
  end

  @spec get_feed_item(Ecto.UUID.t(), Ecto.UUID.t()) :: feed_item | nil
  def get_feed_item(by_user_id, user_id) do
    p =
      by_user_id
      |> not_reported_profiles_q()
      |> where(user_id: ^user_id)

    ActiveSession
    |> where(user_id: ^user_id)
    |> join(:inner, [s], p in subquery(p), on: true)
    |> select([s, p], {p, s})
    |> Repo.one()
  end

  @spec active_sessions_q(Ecto.UUID.t(), String.t() | nil) :: Ecto.Query.t()
  defp active_sessions_q(user_id, nil) do
    ActiveSession
    |> order_by([s], asc: s.flake)
    |> where([s], s.user_id != ^user_id)
  end

  defp active_sessions_q(user_id, last_flake) do
    user_id
    |> active_sessions_q(nil)
    |> where([s], s.flake > ^last_flake)
  end

  defp reported_user_ids_q(user_id) do
    UserReport |> where(from_user_id: ^user_id) |> select([r], r.on_user_id)
  end

  defp invited_user_ids(user_id) do
    q1 = CallInvite |> where([i], i.user_id == ^user_id) |> select([i], i.by_user_id)
    q2 = CallInvite |> where([i], i.by_user_id == ^user_id) |> select([i], i.user_id)
    union(q1, ^q2)
  end

  defp not_hidden_profiles_q do
    where(FeedProfile, hidden?: false)
  end

  defp not_reported_profiles_q(user_id) do
    not_hidden_profiles_q()
    # TODO is inner join faster?
    |> where([p], p.user_id not in subquery(reported_user_ids_q(user_id)))
  end

  defp not_invited_profiles_q(user_id) do
    invited_user_ids = invited_user_ids(user_id)

    user_id
    |> not_reported_profiles_q()
    # TODO might not need this
    |> where([p], p.user_id not in subquery(invited_user_ids))
  end
end
