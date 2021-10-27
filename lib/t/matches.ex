defmodule T.Matches do
  @moduledoc "Likes and matches"

  import Ecto.{Query, Changeset}
  alias Ecto.Multi

  require Logger

  alias T.Repo
  alias T.Matches.{Match, Like, Timeslot}
  alias T.Feeds.FeedProfile
  alias T.Accounts.Profile
  alias T.PushNotifications.DispatchJob
  alias T.Bot

  @type uuid :: Ecto.UUID.t()

  # - PubSub

  @pubsub T.PubSub
  @topic "__m"

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
    m = "New like: #{by_user_id} liked #{user_id}"
    Bot.async_post_message(m)

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
    query = FeedProfile |> where(user_id: ^user_id)

    Multi.update_all(multi, :bump_likes_count, query, inc: [times_liked: 1])
  end

  defp maybe_notify_match(%Match{id: match_id}, by_user_id, user_id) do
    broadcast_from_for_user(by_user_id, {__MODULE__, :matched, %{id: match_id, mate: user_id}})
    broadcast_for_user(user_id, {__MODULE__, :matched, %{id: match_id, mate: by_user_id}})
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
        m = "New match: #{user_id_1} and #{user_id_2}"
        Bot.async_post_message(m)
        Repo.insert(%Match{user_id_1: user_id_1, user_id_2: user_id_2})
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
    |> preload_match_profiles(user_id)
    |> with_timeslots(user_id)
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
      Match
      |> where(user_id_1: ^user_id_1)
      |> where(user_id_2: ^user_id_2)
      |> select([m], m.id)
      |> Repo.delete_all()
      |> case do
        {1, [match_id]} -> {:ok, fn -> notify_unmatch(by_user_id, mate, match_id) end}
        {0, _} -> {:ok, nil}
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
      Match
      |> where(user_id_1: ^uid1)
      |> where(user_id_2: ^uid2)
      |> select([m], %{id: m.id, users: [m.user_id_1, m.user_id_2]})
      |> Repo.delete_all()
      |> case do
        {1, [match]} -> {:ok, match}
        {0, _} -> {:error, :match_not_found}
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

  # TODO cleanup
  defp preload_match_profiles(matches, user_id) do
    mate_matches =
      Map.new(matches, fn match ->
        [mate_id] = [match.user_id_1, match.user_id_2] -- [user_id]
        {mate_id, match}
      end)

    mates = Map.keys(mate_matches)

    profiles =
      FeedProfile
      |> where([p], p.user_id in ^mates)
      |> Repo.all()
      |> Map.new(fn profile -> {profile.user_id, profile} end)

    Enum.map(matches, fn match ->
      [mate_id] = [match.user_id_1, match.user_id_2] -- [user_id]
      profile = Map.fetch!(profiles, mate_id)
      %Match{match | profile: profile}
    end)
  end

  defp with_timeslots(matches, user_id) do
    slots =
      user_id
      # TODO don't reissue join to alive matches
      |> list_relevant_slots()
      |> Map.new(fn %Timeslot{match_id: match_id} = timeslot -> {match_id, timeslot} end)

    Enum.map(matches, fn match ->
      %Match{match | timeslot: slots[match.id]}
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
    Logger.warn(
      "saving slots offer for match #{match_id} (users #{offerer_id}, #{mate_id}) from #{offerer_id}: #{inspect(slots)}"
    )

    m = "Saving slots offer for match: #{offerer_id} offered date  #{mate_id}"
    Bot.async_post_message(m)

    changeset =
      timeslot_changeset(
        %Timeslot{match_id: match_id, picker_id: mate_id},
        %{slots: slots},
        reference
      )

    push_job =
      DispatchJob.new(%{
        "type" => "timeslot_offer",
        "match_id" => match_id,
        "receiver_id" => mate_id
      })

    # conflict_opts = [
    #   on_conflict: [set: [selected_slot: nil, slots: [], picker_id: mate]],
    #   conflict_target: [:match_id]
    # ]

    conflict_opts = [on_conflict: :replace_all, conflict_target: [:match_id]]

    Multi.new()
    |> Multi.insert(:timeslot, changeset, conflict_opts)
    |> Oban.insert(:push, push_job)
    |> Repo.transaction()
    |> case do
      {:ok, %{timeslot: %Timeslot{} = timeslot}} ->
        broadcast_for_user(mate_id, {__MODULE__, [:timeslot, :offered], timeslot})
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

    m = "Accept slot for match: #{picker} with #{mate}"
    Bot.async_post_message(m)

    {:ok, slot, 0} = DateTime.from_iso8601(slot)
    true = DateTime.compare(slot, prev_slot(reference)) in [:eq, :gt]

    {1, [timeslot]} =
      Timeslot
      |> where(match_id: ^match_id)
      |> where(picker_id: ^picker)
      |> where([t], ^slot in t.slots)
      |> select([t], t)
      |> Repo.update_all(set: [selected_slot: slot])

    broadcast_for_user(mate, {__MODULE__, [:timeslot, :accepted], timeslot})

    accepted_push =
      DispatchJob.new(%{
        "type" => "timeslot_accepted",
        "match_id" => match_id,
        "receiver_id" => mate
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

    Oban.insert_all([accepted_push, reminder_push, started_push])

    timeslot
  end

  # TODO delete stale slots
  # can list where I'm picker, where I'm not picker, where slot is selected
  defp list_relevant_slots(user_id) do
    my_matches =
      Match
      |> where([m], m.user_id_1 == ^user_id or m.user_id_2 == ^user_id)

    Timeslot
    |> join(:inner, [t], m in subquery(my_matches), on: t.match_id == m.id)
    |> Repo.all()
  end

  @spec cancel_slot_for_match(uuid, uuid) :: :ok
  def cancel_slot_for_match(by_user_id, match_id) do
    %Match{id: match_id, user_id_1: uid1, user_id_2: uid2} =
      get_match_for_user!(match_id, by_user_id)

    [mate] = [uid1, uid2] -- [by_user_id]
    cancel_slot(by_user_id, match_id, mate)
  end

  @spec cancel_slot_for_matched_user(uuid, uuid) :: :ok
  def cancel_slot_for_matched_user(by_user_id, user_id) do
    [uid1, uid2] = Enum.sort([by_user_id, user_id])
    match_id = get_match_id_for_users!(uid1, uid2)
    cancel_slot(by_user_id, match_id, user_id)
  end

  @spec cancel_slot(uuid, uuid, uuid) :: :ok
  defp cancel_slot(by_user_id, match_id, mate_id) do
    Logger.warn(
      "cancelling timeslot for match #{match_id} (with mate #{mate_id}) by #{by_user_id}"
    )

    m = "Cancelled timeslot: #{by_user_id} cancelled date with #{mate_id}"
    Bot.async_post_message(m)

    {1, [%Timeslot{selected_slot: selected_slot} = timeslot]} =
      Timeslot
      |> where(match_id: ^match_id)
      # |> where([t], t.picker_id in ^[])
      |> select([t], t)
      |> Repo.delete_all()

    broadcast_for_user(mate_id, {__MODULE__, [:timeslot, :cancelled], timeslot})

    if selected_slot do
      push =
        DispatchJob.new(%{
          "type" => "timeslot_cancelled",
          "match_id" => match_id
        })

      Oban.insert_all([push])
    end

    :ok
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
  # ~U[2021-03-23 14:49:00Z] -> ~U[2021-03-23 14:45:00Z]
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

  def notify_timeslot_started(%Match{id: match_id, user_id_1: uid1, user_id_2: uid2}) do
    message = {__MODULE__, [:timeslot, :started], match_id}

    for uid <- [uid1, uid2] do
      broadcast_for_user(uid, message)
    end
  end
end
