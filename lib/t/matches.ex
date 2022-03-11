defmodule T.Matches do
  @moduledoc "Likes and matches"

  import Ecto.{Query, Changeset}
  alias Ecto.Multi

  require Logger

  alias T.Repo
  alias T.Matches.{Match, Like}
  alias T.Feeds.{FeedProfile, SeenProfile}
  alias T.Accounts.Profile
  alias T.PushNotifications.DispatchJob
  alias T.Bot

  @type uuid :: Ecto.UUID.t()

  # - PubSub

  @pubsub T.PubSub
  @topic "__m"

  @seven_days 7 * 24 * 60 * 60

  @doc "Time-to-live for a match without life-prolonging events like calls, meetings, voice-messages"
  def match_ttl, do: @seven_days

  defp pubsub_user_topic(user_id) when is_binary(user_id) do
    @topic <> ":u:" <> String.downcase(user_id)
  end

  def subscribe_for_user(user_id) do
    Phoenix.PubSub.subscribe(@pubsub, pubsub_user_topic(user_id))
  end

  defp broadcast_for_user(user_id, message) do
    Phoenix.PubSub.broadcast(@pubsub, pubsub_user_topic(user_id), message)
  end

  defp broadcast_from_for_user(user_id, message) do
    Phoenix.PubSub.broadcast_from(@pubsub, self(), pubsub_user_topic(user_id), message)
  end

  # - Likes

  @spec like_user(Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, %{match: %Match{} | nil}} | {:error, atom, term, map}
  def like_user(by_user_id, user_id) do
    Multi.new()
    |> mark_liked(by_user_id, user_id)
    |> bump_likes_count(user_id)
    |> match_if_mutual(by_user_id, user_id)
    |> Repo.transaction()
    |> case do
      {:ok, %{match: match}} = success ->
        maybe_notify_match(match, by_user_id, user_id)
        maybe_notify_liked_user(match, by_user_id, user_id)
        success

      {:error, _step, _reason, _changes} = failure ->
        failure
    end
  end

  defp bump_likes_count(multi, user_id) do
    query =
      FeedProfile
      |> where(user_id: ^user_id)
      |> update(inc: [times_liked: 1])
      |> update(
        set: [like_ratio: fragment("(times_liked::decimal + 1) / (times_shown::decimal + 1)")]
      )

    Multi.update_all(multi, :bump_likes_count, query, [])
  end

  defp maybe_notify_match(
         %Match{id: match_id, inserted_at: inserted_at} = match,
         by_user_id,
         user_id
       ) do
    expiration_date = expiration_date(match)

    common = %{
      id: match_id,
      inserted_at: inserted_at,
      expiration_date: expiration_date
    }

    by_user_payload = Map.merge(common, %{mate: user_id})
    user_payload = Map.merge(common, %{mate: by_user_id})

    broadcast_from_for_user(by_user_id, {__MODULE__, :matched, by_user_payload})
    broadcast_for_user(user_id, {__MODULE__, :matched, user_payload})
  end

  defp maybe_notify_match(nil, _by_user_id, _user_id), do: :ok

  defp maybe_notify_liked_user(%Match{id: _match_id}, _by_user_id, _user_id), do: :ok

  defp maybe_notify_liked_user(nil, by_user_id, user_id) do
    broadcast_from_for_user(user_id, {__MODULE__, :liked, %{by_user_id: by_user_id}})
    schedule_liked_push(by_user_id, user_id)
  end

  defp schedule_liked_push(by_user_id, user_id) do
    job = DispatchJob.new(%{"type" => "invite", "by_user_id" => by_user_id, "user_id" => user_id})
    Oban.insert(job)
  end

  defp match_if_mutual(multi, by_user_id, user_id) do
    multi
    |> with_mutual_liker(by_user_id, user_id)
    |> maybe_create_match([by_user_id, user_id])
    |> maybe_schedule_match_push()
  end

  defp with_mutual_liker(multi, by_user_id, user_id) do
    Multi.run(multi, :mutual, fn _repo, _changes ->
      Like
      # if I am liked
      |> where(user_id: ^by_user_id)
      # by who I liked
      |> where(by_user_id: ^user_id)
      |> join(:inner, [pl], p in Profile, on: p.user_id == pl.by_user_id)
      # and who I liked is not hidden
      |> select([..., p], not p.hidden?)
      |> Repo.one()
      |> case do
        # nobody likes me, sad
        _no_liker = nil ->
          {:ok, nil}

        # someone likes me, and they are not hidden
        _not_hidden = true ->
          {:ok, _mutual? = true}

        # somebody likes me, but they are hidden -> like is discarded
        _not_hidden = false ->
          {:ok, _mutual? = false}
      end
    end)
  end

  defp maybe_create_match(multi, user_ids) when is_list(user_ids) do
    Multi.run(multi, :match, fn _repo, %{mutual: mutual} ->
      if mutual do
        [user_id_1, user_id_2] = Enum.sort(user_ids)
        {name1, number_of_matches1} = user_info(user_id_1)
        {name2, number_of_matches2} = user_info(user_id_2)

        m =
          "new match: #{name1} (#{user_id_1}, #{number_of_matches1 + 1} matches) and #{name2} (#{user_id_2}, #{number_of_matches2 + 1})"

        Bot.async_post_message(m)

        Repo.insert(%Match{user_id_1: user_id_1, user_id_2: user_id_2})
      else
        {:ok, nil}
      end
    end)
  end

  defp user_info(user_id) do
    name = FeedProfile |> where(user_id: ^user_id) |> select([p], p.name) |> Repo.one()

    number_of_matches =
      Match
      |> where([m], m.user_id_1 == ^user_id or m.user_id_2 == ^user_id)
      |> select([m], count(m.id))
      |> Repo.one()

    {name, number_of_matches}
  end

  defp maybe_schedule_match_push(multi) do
    Multi.run(multi, :push, fn _repo, %{match: match} ->
      if match, do: schedule_match_push(match), else: {:ok, nil}
    end)
  end

  defp schedule_match_push(%Match{id: match_id}) do
    job = DispatchJob.new(%{"type" => "match", "match_id" => match_id})
    Oban.insert(job)
  end

  @spec mark_liked(Multi.t(), Ecto.UUID.t(), Ecto.UUID.t()) :: Multi.t()
  defp mark_liked(multi, by_user_id, user_id) do
    changeset =
      %Like{by_user_id: by_user_id, user_id: user_id}
      |> change()
      |> unique_constraint(:like, name: :liked_profiles_pkey)

    Multi.insert(multi, :like, changeset)
  end

  @spec decline_like(Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, %{}} | {:error, atom, term, map}
  def decline_like(user_id, liker_id) do
    changeset =
      %Like{by_user_id: liker_id, user_id: user_id}
      |> cast(%{declined: true}, [:declined])

    Repo.update(changeset)
    |> case do
      {:ok, _like} = success ->
        success

      {:error, _step, _reason, _changes} = failure ->
        failure
    end
  end

  # - Matches

  @spec list_matches(uuid) :: [%Match{}]
  def list_matches(user_id) do
    Match
    |> where([m], m.user_id_1 == ^user_id or m.user_id_2 == ^user_id)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
    |> Enum.map(fn match -> %Match{match | expiration_date: expiration_date(match)} end)
    |> preload_match_profiles(user_id)
  end

  defp expiration_date(%Match{inserted_at: inserted_at}) do
    inserted_at
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.add(match_ttl())
  end

  @spec unmatch_match(uuid, uuid) :: boolean
  def unmatch_match(by_user_id, match_id) do
    Logger.warn("#{by_user_id} unmatches match-id=#{match_id}")

    Multi.new()
    |> Multi.run(:unmatch, fn _repo, _changes ->
      Match
      |> where(id: ^match_id)
      |> where([m], m.user_id_1 == ^by_user_id or m.user_id_2 == ^by_user_id)
      |> select([m], [m.user_id_1, m.user_id_2])
      |> Repo.delete_all()
      |> case do
        {1, [user_ids]} -> {:ok, user_ids}
        {0, _} -> {:error, :match_not_found}
      end
    end)
    |> delete_likes()
    |> Repo.transaction()
    |> case do
      {:ok, %{unmatch: user_ids}} when is_list(user_ids) ->
        [mate] = user_ids -- [by_user_id]
        notify_unmatch(by_user_id, mate, match_id)
        _unmatched? = true

      {:error, :unmatch, :match_not_found, _changes} ->
        _unmatched? = false
    end
  end

  # called form accounts on report
  @spec unmatch_multi(Multi.t(), uuid, uuid) :: Multi.t()
  def unmatch_multi(multi, by_user_id, mate) do
    [user_id_1, user_id_2] = Enum.sort([by_user_id, mate])

    Multi.run(multi, :unmatch, fn _repo, _changes ->
      match_id =
        Match
        |> where(user_id_1: ^user_id_1)
        |> where(user_id_2: ^user_id_2)
        |> select([m], m.id)
        |> Repo.one()

      if match_id do
        {1, _} =
          Match
          |> where(id: ^match_id)
          |> Repo.delete_all()

        {:ok, fn -> notify_unmatch(by_user_id, mate, match_id) end}
      else
        {:ok, nil}
      end
    end)
  end

  # called from accounts on report
  def notify_unmatch_changes(%{unmatch: unmatch}) do
    case unmatch do
      notify_unmatch when is_function(notify_unmatch, 0) -> notify_unmatch.()
      nil -> :ok
    end
  end

  @spec unmatch_with_user(uuid, uuid) :: boolean
  def unmatch_with_user(by_user_id, user_id) do
    Logger.warn("#{by_user_id} unmatches with user_id=#{user_id}")
    [uid1, uid2] = Enum.sort([by_user_id, user_id])

    Multi.new()
    |> Multi.run(:unmatch, fn _repo, _changes ->
      match_id =
        Match
        |> where(user_id_1: ^uid1)
        |> where(user_id_2: ^uid2)
        |> select([m], m.id)
        |> Repo.one()

      if match_id do
        {1, _} =
          Match
          |> where(id: ^match_id)
          |> Repo.delete_all()

        {:ok, %{id: match_id, users: [uid1, uid2]}}
      else
        {:error, :match_not_found}
      end
    end)
    |> delete_likes()
    |> Repo.transaction()
    |> case do
      {:ok, %{unmatch: %{id: match_id, users: user_ids}}} ->
        [mate] = user_ids -- [by_user_id]
        notify_unmatch(by_user_id, mate, match_id)
        _unmatched? = true

      {:error, :unmatch, :match_not_found, _changes} ->
        _unmatched? = false
    end
  end

  defp notify_unmatch(by_user_id, mate_id, match_id) do
    broadcast_for_user(mate_id, {__MODULE__, :unmatched, match_id})
    broadcast_from_for_user(by_user_id, {__MODULE__, :unmatched, match_id})
  end

  @spec expire_match(uuid, uuid, uuid) :: boolean
  def expire_match(match_id, user_id_1, user_id_2) do
    {name1, number_of_matches1} = user_info(user_id_1)
    {name2, number_of_matches2} = user_info(user_id_2)

    m =
      "match between #{name1} (#{user_id_1}, #{number_of_matches1} matches) and #{name2} (#{user_id_2}, #{number_of_matches2}) expired"

    Logger.warn(m)
    Bot.async_post_message(m)

    Multi.new()
    |> Multi.run(:unmatch, fn _repo, _changes ->
      Match
      |> where(id: ^match_id)
      |> where(user_id_1: ^user_id_1)
      |> where(user_id_2: ^user_id_2)
      |> select([m], %{id: m.id, users: [m.user_id_1, m.user_id_2]})
      |> Repo.delete_all()
      |> case do
        {1, [match]} -> {:ok, match}
        {0, _} -> {:error, :match_not_found}
      end
    end)
    |> delete_likes()
    |> mark_seen()
    |> Repo.transaction()
    |> case do
      {:ok, %{unmatch: %{id: match_id}}} ->
        notify_expired([user_id_1, user_id_2], match_id)
        _expired? = true

      {:error, :unmatch, :match_not_found, _changes} ->
        _expired? = false
    end
  end

  defp notify_expired(users, match_id) do
    for user_id <- users do
      broadcast_for_user(user_id, {__MODULE__, :expired, match_id})
    end
  end

  # TODO cleanup
  defp preload_match_profiles(matches, user_id) do
    mate_matches =
      Map.new(matches, fn match ->
        [mate_id] = [match.user_id_1, match.user_id_2] -- [user_id]
        {mate_id, match}
      end)

    mates = Map.keys(mate_matches)

    profiles_with_settings =
      FeedProfile
      |> where([p], p.user_id in ^mates)
      |> Repo.all()
      |> Map.new(fn profile -> {profile.user_id, profile} end)

    Enum.map(matches, fn match ->
      [mate_id] = [match.user_id_1, match.user_id_2] -- [user_id]
      %Match{match | profile: Map.fetch!(profiles_with_settings, mate_id)}
    end)
  end

  defp delete_likes(multi) do
    Multi.run(multi, :delete_likes, fn _repo, %{unmatch: unmatch} ->
      [uid1, uid2] =
        case unmatch do
          [_uid1, _uid2] = ids -> ids
          %{users: [_uid1, _uid2] = ids} -> ids
        end

      {count, _} =
        Like
        |> where([l], l.by_user_id == ^uid1 and l.user_id == ^uid2)
        |> or_where([l], l.by_user_id == ^uid2 and l.user_id == ^uid1)
        |> Repo.delete_all()

      {:ok, count}
    end)
  end

  defp mark_seen(multi) do
    Multi.run(multi, :mark_seen, fn _repo, %{unmatch: unmatch} ->
      [uid1, uid2] =
        case unmatch do
          [_uid1, _uid2] = ids -> ids
          %{users: [_uid1, _uid2] = ids} -> ids
        end

      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      {count, _} =
        Repo.insert_all(
          SeenProfile,
          [
            %{by_user_id: uid1, user_id: uid2, inserted_at: now},
            %{by_user_id: uid2, user_id: uid1, inserted_at: now}
          ],
          on_conflict: {:replace, [:inserted_at]},
          conflict_target: [:by_user_id, :user_id]
        )

      {:ok, count}
    end)
  end

  # Expired Matches

  def expiration_prune(reference \\ DateTime.utc_now()) do
    reference
    |> expiration_list_expired_matches()
    |> Enum.each(fn %{id: match_id, user_id_1: user_id_1, user_id_2: user_id_2} ->
      expire_match(match_id, user_id_1, user_id_2)
    end)
  end

  def expiration_list_expired_matches(reference \\ DateTime.utc_now()) do
    expiration_date = DateTime.add(reference, -match_ttl())

    Match
    |> where([m], m.inserted_at < ^expiration_date)
    |> select([m], map(m, [:id, :user_id_1, :user_id_2]))
    |> Repo.all()
  end

  def expiration_notify_soon_to_expire(reference \\ DateTime.utc_now()) do
    expiration_list_soon_to_expire(reference)
    |> Enum.map(fn match_id ->
      DispatchJob.new(%{"type" => "match_about_to_expire", "match_id" => match_id})
    end)
    |> Oban.insert_all()
  end

  defp expiration_notification_interval(reference) do
    to =
      reference
      |> DateTime.add(-match_ttl())
      |> DateTime.add(_24_hours = 24 * 3600)

    from = DateTime.add(to, -60)
    {from, to}
  end

  def expiration_list_soon_to_expire(reference \\ DateTime.utc_now()) do
    {from, to} = expiration_notification_interval(reference)

    Match
    # TODO can result in duplicates with more than one worker
    |> where([m], m.inserted_at > ^from and m.inserted_at <= ^to)
    |> select([m], m.id)
    |> Repo.all()
  end
end
