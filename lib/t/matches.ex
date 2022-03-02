defmodule T.Matches do
  @moduledoc "Likes and matches"

  import Ecto.{Query, Changeset}
  alias Ecto.Multi

  require Logger

  alias T.Repo

  alias T.Matches.{
    Match,
    Like,
    Timeslot,
    MatchEvent,
    ExpiredMatch,
    MatchContact,
    ArchivedMatch,
    Interaction,
    Seen
  }

  alias T.Feeds.FeedProfile
  alias T.Accounts.{Profile, UserSettings}
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
          {:ok,
           %{
             match: %Match{} | nil,
             mutual: %FeedProfile{} | nil,
             audio_only: [boolean] | nil,
             event: %MatchEvent{} | nil
           }}
          | {:error, atom, term, map}
  def like_user(by_user_id, user_id) do
    Multi.new()
    |> mark_liked(by_user_id, user_id)
    |> bump_likes_count(user_id)
    |> match_if_mutual(by_user_id, user_id)
    |> Repo.transaction()
    |> case do
      {:ok, %{match: match, audio_only: audio_only}} = success ->
        maybe_notify_match(match, audio_only, by_user_id, user_id)
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
         [by_user_id_settings, user_id_settings],
         by_user_id,
         user_id
       ) do
    expiration_date = expiration_date(match)

    common = %{
      id: match_id,
      inserted_at: inserted_at,
      expiration_date: expiration_date
    }

    by_user_payload = Map.merge(common, %{mate: user_id, audio_only: user_id_settings})
    user_payload = Map.merge(common, %{mate: by_user_id, audio_only: by_user_id_settings})

    broadcast_from_for_user(by_user_id, {__MODULE__, :matched, by_user_payload})
    broadcast_for_user(user_id, {__MODULE__, :matched, user_payload})
  end

  defp maybe_notify_match(nil, _settings, _by_user_id, _user_id), do: :ok

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
    |> maybe_fetch_settings([by_user_id, user_id])
    |> maybe_create_match_event()
    |> maybe_schedule_match_push()
  end

  defp with_mutual_liker(multi, by_user_id, user_id) do
    Multi.run(multi, :mutual, fn _repo, _changes ->
      maybe_liker =
        Like
        # if I am liked
        |> where(user_id: ^by_user_id)
        # by who I liked
        |> where(by_user_id: ^user_id)
        # and who I liked is not hidden
        |> join(:inner, [pl], p in FeedProfile, on: p.user_id == pl.by_user_id and not p.hidden?)
        # then I have a mate
        |> select([..., p], p)
        |> Repo.one()

      {:ok, maybe_liker}
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

  defp maybe_fetch_settings(multi, [by_user_id, user_id]) do
    Multi.run(multi, :audio_only, fn _repo, %{mutual: mutual} ->
      if mutual do
        by_user_id_settings =
          UserSettings |> where(user_id: ^by_user_id) |> select([s], s.audio_only) |> Repo.one!()

        user_id_settings =
          UserSettings |> where(user_id: ^user_id) |> select([s], s.audio_only) |> Repo.one!()

        {:ok, [by_user_id_settings, user_id_settings]}
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

  defp maybe_create_match_event(multi) do
    Multi.run(multi, :event, fn _repo, %{match: match} ->
      if match do
        Repo.insert(%MatchEvent{
          timestamp: DateTime.utc_now() |> DateTime.truncate(:second),
          match_id: match.id,
          event: "created"
        })
      else
        {:ok, nil}
      end
    end)
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

  @spec mark_like_seen(uuid, uuid) :: :ok
  def mark_like_seen(user_id, by_user_id) do
    Like
    |> where(by_user_id: ^by_user_id)
    |> where(user_id: ^user_id)
    |> Repo.update_all(set: [seen: true])

    :ok
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
    last_interaction_q =
      Interaction
      |> where(match_id: parent_as(:match).id)
      |> order_by(desc: :id)
      |> limit(1)

    matches_with_undying_events_q()
    |> where([match: m], m.user_id_1 == ^user_id or m.user_id_2 == ^user_id)
    |> where([match: m], m.id not in subquery(archived_match_ids_q(user_id)))
    |> order_by(desc: :inserted_at)
    |> join(:left, [m], s in Seen, as: :seen, on: s.match_id == m.id and s.user_id == ^user_id)
    |> join(:left, [m], t in assoc(m, :timeslot), as: :t)
    |> join(:left, [m], c in assoc(m, :contact), as: :c)
    |> join(:left, [m], v in assoc(m, :voicemail), as: :v)
    |> join(:left_lateral, [m], i in subquery(last_interaction_q), as: :last_interaction)
    # TODO aggregate voicemail
    |> preload([t: t, c: c, v: v], timeslot: t, contact: c, voicemail: v)
    |> select(
      [match: m, undying_event: e, last_interaction: i, seen: s],
      {m, e.timestamp, i.id, s.match_id}
    )
    |> Repo.all()
    |> Enum.map(fn {match, undying_event_timestamp, last_interaction_id, seen_match_id} ->
      expiration_date =
        unless undying_event_timestamp do
          expiration_date(match)
        end

      %Match{
        match
        | last_interaction_id: last_interaction_id,
          expiration_date: expiration_date,
          seen: !!seen_match_id
      }
    end)
    |> preload_match_profiles(user_id)
  end

  defp expiration_date(%Match{inserted_at: inserted_at}) do
    inserted_at
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.add(match_ttl())
  end

  def fetch_mate_id(by_user_id, match_id) do
    match_q = where(Match, id: ^match_id)
    match_q_1 = match_q |> where(user_id_1: ^by_user_id) |> select([m], m.user_id_2)
    match_q_2 = match_q |> where(user_id_2: ^by_user_id) |> select([m], m.user_id_1)
    match_q_1 |> union(^match_q_2) |> Repo.one()
  end

  defp archived_match_ids_q(user_id) do
    ArchivedMatch |> where(by_user_id: ^user_id) |> select([m], m.match_id)
  end

  @spec mark_match_seen(uuid, uuid) :: :ok
  def mark_match_seen(by_user_id, match_id) do
    Repo.insert_all(Seen, [%{user_id: by_user_id, match_id: match_id}], on_conflict: :nothing)
    :ok
  end

  @spec list_expired_matches(uuid) :: [%Match{}]
  def list_expired_matches(user_id) do
    ExpiredMatch
    |> where([m], m.user_id == ^user_id)
    |> order_by(asc: :inserted_at)
    |> join(:inner, [m], p in FeedProfile, on: m.with_user_id == p.user_id)
    |> select([m, p], {m, p})
    |> Repo.all()
    |> Enum.map(fn {match, feed_profile} ->
      %ExpiredMatch{match | profile: feed_profile}
    end)
  end

  @spec list_archived_matches(any) :: list
  def list_archived_matches(user_id) do
    ArchivedMatch
    |> where([m], m.by_user_id == ^user_id)
    |> order_by(desc: :inserted_at)
    |> join(:inner, [m], p in FeedProfile, on: m.with_user_id == p.user_id)
    |> select([m, p], {m, p})
    |> Repo.all()
    |> Enum.map(fn {match, feed_profile} ->
      %ArchivedMatch{match | profile: feed_profile}
    end)
  end

  def mark_match_archived(match_id, by_user_id) do
    %Match{id: match_id, user_id_1: uid1, user_id_2: uid2} =
      get_match_for_user!(match_id, by_user_id)

    [mate] = [uid1, uid2] -- [by_user_id]

    Repo.insert!(%ArchivedMatch{match_id: match_id, by_user_id: by_user_id, with_user_id: mate})
  end

  def unarchive_match(match_id, by_user_id) do
    ArchivedMatch
    |> where(match_id: ^match_id)
    |> where(by_user_id: ^by_user_id)
    |> Repo.delete_all()
  end

  @spec unmatch_match(uuid, uuid) :: boolean
  def unmatch_match(by_user_id, match_id) do
    Logger.warn("#{by_user_id} unmatches match-id=#{match_id}")

    Multi.new()
    |> delete_voicemail(match_id)
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
        :ok = T.Calls.voicemail_delete_all(match_id)

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
        :ok = T.Calls.voicemail_delete_all(match_id)

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

    number_of_events =
      MatchEvent |> where(match_id: ^match_id) |> select([e], count(e.timestamp)) |> Repo.one!()

    m =
      "match between #{name1} (#{user_id_1}, #{number_of_matches1} matches) and #{name2} (#{user_id_2}, #{number_of_matches2}) expired, there were #{number_of_events - 1} events between them"

    Logger.warn(m)
    Bot.async_post_message(m)

    Multi.new()
    |> delete_voicemail(match_id)
    |> Multi.run(:unmatch, fn _repo, _changes ->
      Match
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
    |> insert_expired_match()
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
      |> join(:left, [p], s in UserSettings, on: p.user_id == s.user_id)
      |> select([p, s], {p, s})
      |> Repo.all()
      |> Map.new(fn {profile, settings} -> {profile.user_id, {profile, settings.audio_only}} end)

    Enum.map(matches, fn match ->
      [mate_id] = [match.user_id_1, match.user_id_2] -- [user_id]
      {profile, audio_only} = Map.fetch!(profiles_with_settings, mate_id)
      %Match{match | profile: profile, audio_only: audio_only}
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

  # note this needs to run before match delete
  # otherwise DB records would be CASCADE deleted already
  # and we wouldn't know s3_keys to delete
  defp delete_voicemail(multi, match_id) do
    Multi.run(multi, :voicemail, fn _repo, _changes ->
      :ok = T.Calls.voicemail_delete_all(match_id)
      {:ok, nil}
    end)
  end

  defp insert_expired_match(multi) do
    Multi.insert_all(multi, :insert_expired_match, ExpiredMatch, fn %{unmatch: unmatch} ->
      %{id: match_id, users: [user_id_1, user_id_2]} = unmatch

      timestamp = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_naive()

      [
        %{
          match_id: match_id,
          user_id: user_id_1,
          with_user_id: user_id_2,
          inserted_at: timestamp
        },
        %{
          match_id: match_id,
          user_id: user_id_2,
          with_user_id: user_id_1,
          inserted_at: timestamp
        }
      ]
    end)
  end

  # - Timeslots

  @type iso_8601 :: String.t()

  @spec save_slots_offer_for_match(uuid, uuid, [iso_8601], DateTime.t()) ::
          {:ok, %Timeslot{}} | {:error, %Ecto.Changeset{}}
  def save_slots_offer_for_match(offerer, match_id, slots, reference \\ DateTime.utc_now()) do
    %Match{id: match_id, user_id_1: uid1, user_id_2: uid2} =
      get_match_for_user!(match_id, offerer)

    [mate] = [uid1, uid2] -- [offerer]
    save_slots_offer(offerer, mate, match_id, slots, reference)
  end

  @spec save_slots_offer_for_user(uuid, uuid, [iso_8601], DateTime.t()) ::
          {:ok, %Timeslot{}} | {:error, %Ecto.Changeset{}}
  def save_slots_offer_for_user(offerer, mate, slots, reference \\ DateTime.utc_now()) do
    [uid1, uid2] = Enum.sort([offerer, mate])
    match_id = get_match_id_for_users!(uid1, uid2)
    save_slots_offer(offerer, mate, match_id, slots, reference)
  end

  @spec save_slots_offer(uuid, uuid, uuid, [iso_8601 :: String.t()], DateTime.t()) ::
          {:ok, %Timeslot{}} | {:error, %Ecto.Changeset{}}
  defp save_slots_offer(offerer_id, mate_id, match_id, slots, reference) do
    m =
      "saving slots offer for match #{match_id} (users #{offerer_id}, #{mate_id}) from #{offerer_id}: #{inspect(slots)}"

    Logger.warn(m)
    now = DateTime.truncate(reference, :second)
    inserted_at = DateTime.to_naive(now)

    changeset =
      timeslot_changeset(
        %Timeslot{match_id: match_id, picker_id: mate_id, inserted_at: inserted_at},
        %{slots: slots},
        reference
      )

    push_job =
      DispatchJob.new(%{
        "type" => "timeslot_offer",
        "match_id" => match_id,
        "receiver_id" => mate_id,
        "offerer_id" => offerer_id
      })

    match_events = %MatchEvent{
      timestamp: now,
      match_id: match_id,
      event: "slot_save"
    }

    # conflict_opts = [
    #   on_conflict: [set: [selected_slot: nil, slots: [], picker_id: mate]],
    #   conflict_target: [:match_id]
    # ]

    conflict_opts = [on_conflict: :replace_all, conflict_target: [:match_id]]

    Multi.new()
    |> Multi.insert(:timeslot, changeset, conflict_opts)
    |> Multi.insert(:match_event, match_events)
    |> Multi.insert(:interaction, fn %{timeslot: timeslot} ->
      %Interaction{
        from_user_id: offerer_id,
        to_user_id: mate_id,
        match_id: match_id,
        data: %{"type" => "slots_offer", "slots" => timeslot.slots}
      }
    end)
    |> Oban.insert(:push, push_job)
    |> Repo.transaction()
    |> case do
      {:ok, %{timeslot: %Timeslot{} = timeslot, interaction: interaction}} ->
        maybe_unarchive_match(match_id)
        broadcast_for_user(mate_id, {__MODULE__, [:timeslot, :offered], timeslot})
        broadcast_interaction(interaction)

        {:ok, timeslot}

      {:error, :timeslot, %Ecto.Changeset{} = changeset, _changes} ->
        {:error, changeset}
    end
  end

  @spec accept_slot_for_match(uuid, uuid, iso_8601, DateTime.t()) :: %Timeslot{}
  def accept_slot_for_match(picker, match_id, slot, reference \\ DateTime.utc_now()) do
    %Match{id: match_id, user_id_1: uid1, user_id_2: uid2} = get_match_for_user!(match_id, picker)
    [mate] = [uid1, uid2] -- [picker]
    accept_slot(picker, mate, match_id, slot, reference)
  end

  @spec accept_slot_for_matched_user(uuid, uuid, iso_8601, DateTime.t()) :: %Timeslot{}
  def accept_slot_for_matched_user(picker, mate, slot, reference \\ DateTime.utc_now()) do
    [uid1, uid2] = Enum.sort([picker, mate])
    match_id = get_match_id_for_users!(uid1, uid2)
    accept_slot(picker, mate, match_id, slot, reference)
  end

  @spec accept_slot(uuid, uuid, uuid, iso_8601, DateTime.t()) :: %Timeslot{}
  defp accept_slot(picker, mate, match_id, slot, reference) do
    Logger.warn(
      "accepting slot for match #{match_id} (users #{picker}, #{mate}) by #{picker}: #{inspect(slot)}"
    )

    {:ok, slot, 0} = DateTime.from_iso8601(slot)
    accepted_at = DateTime.truncate(reference, :second)

    {picker_name, _number_of_matches1} = user_info(picker)
    {mate_name, _umber_of_matches2} = user_info(mate)

    seconds = slot |> DateTime.diff(DateTime.utc_now())
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)

    m =
      "accept slot #{picker_name} (#{picker}) with #{mate_name} (#{mate}) in #{hours}h #{minutes}m"

    Bot.async_post_message(m)

    match_event = %MatchEvent{
      timestamp: accepted_at,
      match_id: match_id,
      event: "slot_accept"
    }

    interaction = %Interaction{
      from_user_id: picker,
      to_user_id: mate,
      match_id: match_id,
      data: %{"type" => "slot_accept", "slot" => slot}
    }

    true = DateTime.compare(slot, prev_slot(reference)) in [:eq, :gt]
    timeslot_started? = DateTime.compare(slot, reference) in [:lt, :eq]

    if timeslot_started? do
      notify_timeslot_started(match_id, [picker, mate])
    end

    pushes =
      if timeslot_started? do
        _now_push =
          DispatchJob.new(%{
            "type" => "timeslot_accepted_now",
            "match_id" => match_id,
            "receiver_id" => mate,
            "picker_id" => picker,
            "slot" => slot
          })
      else
        accepted_push =
          DispatchJob.new(%{
            "type" => "timeslot_accepted",
            "match_id" => match_id,
            "receiver_id" => mate,
            "picker_id" => picker,
            "slot" => slot
          })

        reminder_push =
          DispatchJob.new(
            %{"type" => "timeslot_reminder", "match_id" => match_id, "slot" => slot},
            scheduled_at: DateTime.add(slot, -15 * 60, :second)
          )

        started_push =
          DispatchJob.new(
            %{"type" => "timeslot_started", "match_id" => match_id, "slot" => slot},
            scheduled_at: slot
          )

        [accepted_push, reminder_push, started_push]
      end

    {:ok, %{accept: timeslot, interaction: interaction}} =
      Multi.new()
      |> Multi.run(:accept, fn _repo, _changes ->
        Timeslot
        |> where(match_id: ^match_id)
        |> where(picker_id: ^picker)
        |> where([t], ^slot in t.slots)
        |> select([t], t)
        |> Repo.update_all(set: [selected_slot: slot, accepted_at: accepted_at])
        |> case do
          {1, [timeslot]} -> {:ok, timeslot}
          {0, _} -> {:error, :not_found}
        end
      end)
      |> Multi.insert(:interaction, interaction)
      |> Multi.insert(:event, match_event)
      |> Oban.insert_all(:pushes, List.wrap(pushes))
      |> Repo.transaction()

    broadcast_for_user(mate, {__MODULE__, [:timeslot, :accepted], timeslot})
    broadcast_interaction(interaction)
    timeslot
  end

  @spec cancel_slot_for_match(uuid, uuid) :: :ok
  def cancel_slot_for_match(by_user_id, match_id) do
    %Match{id: match_id, user_id_1: uid1, user_id_2: uid2} =
      get_match_for_user!(match_id, by_user_id)

    [mate] = [uid1, uid2] -- [by_user_id]
    cancel_slot(by_user_id, mate, match_id)
  end

  @spec cancel_slot_for_matched_user(uuid, uuid) :: :ok
  def cancel_slot_for_matched_user(by_user_id, user_id) do
    [uid1, uid2] = Enum.sort([by_user_id, user_id])
    match_id = get_match_id_for_users!(uid1, uid2)
    cancel_slot(by_user_id, user_id, match_id)
  end

  @spec cancel_slot(uuid, uuid, uuid) :: :ok
  defp cancel_slot(by_user_id, mate_id, match_id) do
    Logger.warn(
      "cancelling timeslot for match #{match_id} (with mate #{mate_id}) by #{by_user_id}"
    )

    match_event = %MatchEvent{
      timestamp: DateTime.truncate(DateTime.utc_now(), :second),
      match_id: match_id,
      event: "slot_cancel"
    }

    interaction = %Interaction{
      from_user_id: by_user_id,
      to_user_id: mate_id,
      match_id: match_id,
      data: %{"type" => "slot_cancel"}
    }

    {:ok, %{cancel: %Timeslot{selected_slot: selected_slot} = timeslot, interaction: interaction}} =
      Multi.new()
      |> Multi.run(:cancel, fn _repo, _changes ->
        Timeslot
        |> where(match_id: ^match_id)
        # |> where([t], t.picker_id in ^[])
        |> select([t], t)
        |> Repo.delete_all()
        |> case do
          {1, [timeslot]} -> {:ok, timeslot}
          {0, _} -> {:error, :not_found}
        end
      end)
      |> Multi.insert(:interaction, interaction)
      |> Multi.insert(:event, match_event)
      |> Repo.transaction()

    broadcast_for_user(mate_id, {__MODULE__, [:timeslot, :cancelled], timeslot})
    broadcast_interaction(interaction)

    if selected_slot do
      {canceller_name, _number_of_matches1} = user_info(by_user_id)
      {cancelled_name, _umber_of_matches2} = user_info(mate_id)

      seconds = DateTime.utc_now() |> DateTime.diff(selected_slot)
      hours = div(seconds, 3600)
      minutes = div(rem(seconds, 3600), 60)

      m =
        "cancelled slot #{canceller_name} (#{by_user_id}) cancelled slot with #{cancelled_name} (#{mate_id}) in #{hours}h #{minutes}m"

      Bot.async_post_message(m)

      push =
        DispatchJob.new(%{
          "type" => "timeslot_cancelled",
          "match_id" => match_id,
          "receiver_id" => mate_id,
          "canceller_id" => by_user_id,
          "slot" => selected_slot
        })

      Oban.insert_all([push])
    end

    :ok
  end

  def save_contacts_offer_for_match(offerer, match_id, contacts, now \\ DateTime.utc_now()) do
    %Match{id: match_id, user_id_1: uid1, user_id_2: uid2} =
      get_match_for_user!(match_id, offerer)

    [mate] = [uid1, uid2] -- [offerer]
    save_contacts_offer(offerer, mate, match_id, contacts, now)
  end

  defp save_contacts_offer(offerer, mate, match_id, contacts, now) do
    {offerer_name, _number_of_matches1} = user_info(offerer)
    {mate_name, _umber_of_matches2} = user_info(mate)
    now = DateTime.truncate(now, :second)
    inserted_at = DateTime.to_naive(now)

    m = "contact offer from #{offerer_name} (#{offerer}) to #{mate_name} (#{mate})"

    Logger.warn(m)
    Bot.async_post_message(m)

    changeset =
      contact_changeset(
        %MatchContact{match_id: match_id, picker_id: mate, inserted_at: inserted_at},
        %{contacts: contacts}
      )

    match_event = %MatchEvent{
      timestamp: now,
      match_id: match_id,
      event: "contact_offer"
    }

    interaction = %Interaction{
      data: %{"type" => "contact_offer", "contacts" => contacts},
      match_id: match_id,
      from_user_id: offerer,
      to_user_id: mate
    }

    push_job =
      DispatchJob.new(%{
        "type" => "contact_offer",
        "match_id" => match_id,
        "receiver_id" => mate,
        "offerer_id" => offerer
      })

    conflict_opts = [on_conflict: :replace_all, conflict_target: [:match_id]]

    Multi.new()
    |> Multi.insert(:match_contact, changeset, conflict_opts)
    |> Multi.insert(:match_event, match_event)
    |> Multi.insert(:interaction, interaction)
    |> Oban.insert(:push, push_job)
    |> Repo.transaction()
    |> case do
      {:ok, %{match_contact: %MatchContact{} = match_contact, interaction: interaction}} ->
        maybe_unarchive_match(match_id)
        broadcast_for_user(mate, {__MODULE__, [:contact, :offered], match_contact})
        broadcast_interaction(interaction)
        {:ok, match_contact}

      {:error, :match_contact, %Ecto.Changeset{} = changeset, _changes} ->
        {:error, changeset}
    end
  end

  def save_contact_click(match_id, now \\ DateTime.utc_now()) do
    match_event = %MatchEvent{
      timestamp: DateTime.truncate(now, :second),
      match_id: match_id,
      event: "contact_click"
    }

    Repo.insert(match_event)
  end

  def open_contact_for_match(me, match_id, contact_type, now \\ DateTime.utc_now()) do
    m = "contact opened for match #{match_id} by #{me}"
    seen_at = DateTime.truncate(now, :second)

    Logger.warn(m)
    Bot.async_post_message(m)

    {1, _} =
      MatchContact
      |> where(match_id: ^match_id)
      |> Repo.update_all(set: [opened_contact_type: contact_type, seen_at: seen_at])

    :ok
  end

  def report_meeting(me, match_id) do
    m = "meeting reported for match #{match_id} by #{me}"

    Logger.warn(m)
    Bot.async_post_message(m)

    Multi.new()
    |> Multi.delete_all(:match_contact, MatchContact |> where(match_id: ^match_id))
    |> Multi.insert(:match_event, %MatchEvent{
      timestamp: DateTime.truncate(DateTime.utc_now(), :second),
      match_id: match_id,
      event: "meeting_report"
    })
    |> Repo.transaction()
    |> case do
      {:ok, _changes} -> :ok
      {:error, _changes} -> :error
    end
  end

  def mark_contact_not_opened(me, match_id) do
    m = "haven't yet met for match #{match_id} by #{me}"

    Logger.warn(m)
    Bot.async_post_message(m)

    {1, _} =
      MatchContact
      |> where(match_id: ^match_id)
      |> Repo.update_all(set: [opened_contact_type: nil])

    :ok
  end

  defp maybe_unarchive_match(match_id) do
    ArchivedMatch |> where(match_id: ^match_id) |> Repo.delete_all()
  end

  @spec get_match_id([uuid]) :: uuid | nil
  def get_match_id(users) do
    [user_id_1, user_id_2] = Enum.sort(users)

    Match
    |> where(user_id_1: ^user_id_1)
    |> where(user_id_2: ^user_id_2)
    |> select([m], m.id)
    |> Repo.one()
  end

  defp get_match_id_for_users!(user_id_1, user_id_2) do
    Match
    |> where(user_id_1: ^user_id_1)
    |> where(user_id_2: ^user_id_2)
    |> select([m], m.id)
    |> Repo.one!()
  end

  defp get_match_for_user!(match_id, user_id) do
    Match
    |> where(id: ^match_id)
    |> where([m], m.user_id_1 == ^user_id or m.user_id_2 == ^user_id)
    |> Repo.one!()
    |> preload_mate!(user_id)
  end

  defp preload_mate!(match, user_id) do
    [mate_id] = [match.user_id_1, match.user_id_2] -- [user_id]
    mate = Repo.get!(Profile, mate_id)
    %Match{match | profile: mate}
  end

  defp timeslot_changeset(timeslot, attrs, reference) do
    timeslot
    |> cast(attrs, [:slots])
    |> update_change(:slots, &filter_valid_slots(&1, reference))
    |> validate_required([:slots])
    |> validate_length(:slots, min: 1)
  end

  defp filter_valid_slots(slots, reference) do
    slots
    |> Enum.map(&parse_slot/1)
    |> Enum.filter(&future_slot?(&1, reference))
    |> Enum.uniq_by(&DateTime.to_unix/1)
  end

  defp parse_slot(timestamp) when is_binary(timestamp) do
    {:ok, dt, 0} = DateTime.from_iso8601(timestamp)
    dt
  end

  defp parse_slot(%DateTime{} = dt), do: dt

  defp future_slot?(datetime, reference) do
    # TODO within_24h? =
    DateTime.compare(datetime, prev_slot(reference)) in [:eq, :gt]
  end

  # ~U[2021-03-23 14:12:00Z] -> ~U[2021-03-23 14:00:00Z]
  # ~U[2021-03-23 14:49:00Z] -> ~U[2021-03-23 14:30:00Z]
  defp prev_slot(%DateTime{minute: minutes} = dt) do
    %DateTime{dt | minute: div(minutes, 30) * 30, second: 0, microsecond: {0, 0}}
  end

  def schedule_timeslot_ended(match, timeslot) do
    ended_at = DateTime.add(timeslot.selected_slot, 60 * 60, :second)

    job =
      DispatchJob.new(
        %{"type" => "timeslot_ended", "match_id" => match.id},
        scheduled_at: ended_at
      )

    Oban.insert!(job)
  end

  def notify_timeslot_ended(%Match{id: match_id, user_id_1: uid1, user_id_2: uid2}) do
    message = {__MODULE__, [:timeslot, :ended], match_id}

    for uid <- [uid1, uid2] do
      broadcast_for_user(uid, message)
    end
  end

  def notify_timeslot_started(match_id, user_ids) do
    message = {__MODULE__, [:timeslot, :started], match_id}

    for uid <- user_ids do
      broadcast_for_user(uid, message)
    end
  end

  def notify_timeslot_started(%Match{id: match_id, user_id_1: uid1, user_id_2: uid2}) do
    message = {__MODULE__, [:timeslot, :started], match_id}

    for uid <- [uid1, uid2] do
      broadcast_for_user(uid, message)
    end
  end

  def notify_match_expiration_reset(match_id, user_ids) do
    message = {__MODULE__, :expiration_reset, match_id}

    for uid <- user_ids do
      broadcast_for_user(uid, message)
    end
  end

  # Expired Matches

  def expiration_prune(reference \\ DateTime.utc_now()) do
    reference
    |> expiration_list_expired_matches()
    |> Enum.each(fn %{id: match_id, user_id_1: user_id_1, user_id_2: user_id_2} ->
      expire_match(match_id, user_id_1, user_id_2)
    end)
  end

  def prune_stale_timeslots(reference \\ DateTime.utc_now()) do
    offer_expiration_date = DateTime.add(reference, -30 * 60)
    selected_slot_expiration_date = DateTime.add(reference, -60 * 60)

    unnested_slots =
      select(Timeslot, [t], %{match_id: t.match_id, slots: fragment("unnest(?)", t.slots)})

    max_slots =
      from(t in subquery(unnested_slots))
      |> group_by([t], t.match_id)
      |> select([t], %{match_id: t.match_id, max: max(t.slots)})

    matches_with_old_slots =
      from(t in subquery(max_slots))
      |> where([t], t.max < ^offer_expiration_date)
      |> select([t], t.match_id)

    Timeslot
    |> where([t], is_nil(t.selected_slot) and t.match_id in subquery(matches_with_old_slots))
    |> or_where([t], t.selected_slot < ^selected_slot_expiration_date)
    |> Repo.delete_all()
  end

  def expiration_list_expired_matches(reference \\ DateTime.utc_now()) do
    expiration_date = DateTime.add(reference, -match_ttl())

    expiring_matches_q()
    |> where(
      [match: m],
      m.inserted_at < ^expiration_date
    )
    |> select([match: m], map(m, [:id, :user_id_1, :user_id_2]))
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

    expiring_matches_q()
    # TODO can result in duplicates with more than one worker
    |> where(
      [match: m],
      m.inserted_at > ^from and m.inserted_at <= ^to
    )
    |> select([m], m.id)
    |> Repo.all()
  end

  def delete_expired_match(match_id, by_user_id) do
    ExpiredMatch
    |> where(match_id: ^match_id, user_id: ^by_user_id)
    |> Repo.delete_all()
  end

  defp named_match_q do
    from m in Match, as: :match
  end

  defp expiring_matches_q(query \\ named_match_q()) do
    query
    |> matches_with_undying_events_q()
    |> where([undying_event: e], is_nil(e.timestamp))
  end

  def matches_with_undying_events_q(query \\ named_match_q()) do
    undying_events_q =
      MatchEvent
      |> where(match_id: parent_as(:match).id)
      |> where(
        [e],
        e.event == "call_start" or e.event == "contact_offer" or e.event == "contact_click"
      )
      |> select([e], e.timestamp)
      |> limit(1)

    join(query, :left_lateral, [m], e in subquery(undying_events_q), as: :undying_event)
  end

  # Contact Exchange

  defp contact_changeset(contact, attrs) do
    contact
    |> cast(attrs, [:contacts])
    |> validate_required([:contacts])
    |> validate_change(:contacts, fn :contacts, contacts ->
      case contacts
           |> Map.keys()
           |> Enum.find(fn key ->
             key not in ["whatsapp", "telegram", "instagram", "phone"]
           end) do
        nil -> []
        _ -> [contacts: "unrecognized contact type"]
      end
    end)
  end

  # History

  @spec history_list_interactions(uuid) :: [%Interaction{}]
  def history_list_interactions(match_id) do
    Interaction
    |> where(match_id: ^match_id)
    |> order_by(asc: :id)
    |> Repo.all()
  end

  @spec broadcast_interaction(%Interaction{}) :: :ok
  def broadcast_interaction(%Interaction{from_user_id: from, to_user_id: to} = interaction) do
    message = {__MODULE__, :interaction, interaction}
    broadcast_for_user(from, message)
    broadcast_for_user(to, message)
    :ok
  end
end
