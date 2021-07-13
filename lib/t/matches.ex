defmodule T.Matches do
  @moduledoc """
  User wants to fetch their active matches? Do they want to unmatch?
  Or maybe they want to send a message to their match?

  Then this is the palce to add code for it.
  """

  import Ecto.Query
  import T.Gettext

  alias T.{Repo, Media, Accounts, PushNotifications, Bot}
  alias T.Accounts.Profile
  alias T.Matches.{Match, SeenMatch, Message, Yo, Timeslot}
  alias T.Feeds.ProfileLike

  @pubsub T.PubSub
  @topic to_string(__MODULE__)

  defp pubsub_match_topic(match_id) when is_binary(match_id) do
    @topic <> ":" <> String.downcase(match_id)
  end

  defp pubsub_user_topic(user_id) when is_binary(user_id) do
    @topic <> ":u:" <> String.downcase(user_id)
  end

  def subscribe_for_match(match_id) do
    Phoenix.PubSub.subscribe(@pubsub, pubsub_match_topic(match_id))
  end

  def unsubscribe_from_match(match_id) do
    Phoenix.PubSub.unsubscribe(@pubsub, pubsub_match_topic(match_id))
  end

  def subscribe_for_user(user_id) do
    Phoenix.PubSub.subscribe(@pubsub, pubsub_user_topic(user_id))
  end

  defp notify_subscribers({:ok, user_ids} = success, [:unmatched, match_id] = event) do
    msg = {__MODULE__, event, user_ids}
    Phoenix.PubSub.broadcast(@pubsub, pubsub_match_topic(match_id), msg)
    success
  end

  defp notify_subscribers({:ok, %{match: match}} = success, [:matched]) do
    if match do
      %Match{id: match_id, user_id_1: uid1, user_id_2: uid2} = match
      uids = Enum.map([uid1, uid2], &String.downcase/1)
      msg = {__MODULE__, [:matched, match_id], uids}

      for topic <- [pubsub_user_topic(uid1), pubsub_user_topic(uid2)] do
        Phoenix.PubSub.broadcast(@pubsub, topic, msg)
      end
    end

    success
  end

  defp notify_subscribers({:ok, %{timeslot: timeslot}} = success, event) do
    _ = notify_subscribers({:ok, timeslot}, event)
    success
  end

  defp notify_subscribers({:ok, %Timeslot{} = timeslot} = success, [:timeslot, event, to_mate])
       when event in [:offered, :accepted, :cancelled] do
    Phoenix.PubSub.broadcast(
      @pubsub,
      pubsub_user_topic(to_mate),
      {__MODULE__, [:timeslot, event], timeslot}
    )

    success
  end

  defp notify_subscribers({:error, _reason} = error, _event) do
    error
  end

  defp notify_subscribers({:error, _step, _reason, _changes} = error, _event) do
    error
  end

  ##################### MATCH #####################

  def match_if_mutual_m(multi, by_user_id, user_id) do
    multi
    |> with_mutual_liker(by_user_id, user_id)
    |> maybe_create_match([by_user_id, user_id])
    |> maybe_schedule_push()
  end

  def match_if_mutual(by_user_id, user_id) do
    Ecto.Multi.new()
    |> match_if_mutual_m(by_user_id, user_id)
    |> Repo.transaction()
    |> maybe_notify_of_match()
  end

  def maybe_notify_of_match(result) do
    notify_subscribers(result, [:matched])
  end

  defp with_mutual_liker(multi, by_user_id, user_id) do
    Ecto.Multi.run(multi, :mutual, fn _repo, _changes ->
      ProfileLike
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

        # someone likes me, and they are not hidden! meaning they are
        # - not fully matched
        # - not pending deletion
        # - not blocked
        _not_hidden = true ->
          {:ok, _mutual? = true}

        # somebody likes me, but they are hidden -> like is discarded
        _not_hidden = false ->
          {:ok, _mutual? = false}
      end
    end)
  end

  defp maybe_create_match(multi, user_ids) when is_list(user_ids) do
    Ecto.Multi.run(multi, :match, fn _repo, %{mutual: mutual} ->
      if mutual do
        [user_id_1, user_id_2] = Enum.sort(user_ids)
        Repo.insert(%Match{user_id_1: user_id_1, user_id_2: user_id_2})
      else
        {:ok, nil}
      end
    end)
  end

  defp maybe_schedule_push(multi) do
    Ecto.Multi.run(multi, :push, fn _repo, %{match: match} ->
      if match, do: schedule_match_push(match), else: {:ok, nil}
    end)
  end

  defp schedule_match_push(%Match{id: match_id}) do
    job = PushNotifications.DispatchJob.new(%{"type" => "match", "match_id" => match_id})
    Oban.insert(job)
  end

  # defp schedule_yo_push(%Match{id: match_id}, sender_id) do
  #   job =
  #     PushNotifications.DispatchJob.new(%{
  #       "type" => "yo",
  #       "match_id" => match_id,
  #       "sender_id" => sender_id
  #     })

  #   Oban.insert(job)
  # end

  ######################## DATE SLOTS ########################

  import Ecto.Changeset

  # TODO ensure slots are 15-minute
  @doc "save_slots_offer(utc_timestamps, match: <match_id>, from: <user_id>)"
  def save_slots_offer(slots, opts) do
    match_id = Keyword.fetch!(opts, :match)
    offerer = Keyword.fetch!(opts, :from)
    reference = prev_slot(opts[:reference] || DateTime.utc_now())

    %Match{id: match_id, user_id_1: uid1, user_id_2: uid2} = get_match_for_user(match_id, offerer)
    [mate] = [uid1, uid2] -- [offerer]

    Bot.async_post_silent_message(
      "saving slots offer for match #{match_id} (users #{uid1}, #{uid2}) from #{offerer}: #{inspect(slots)}"
    )

    changeset =
      timeslot_changeset(
        %Timeslot{match_id: match_id, picker_id: mate},
        %{slots: slots},
        reference
      )

    push_job =
      PushNotifications.DispatchJob.new(%{
        "type" => "timeslot_offer",
        "match_id" => match_id,
        "receiver_id" => mate
      })

    # conflict_opts = [
    #   on_conflict: [set: [selected_slot: nil, slots: [], picker_id: mate]],
    #   conflict_target: [:match_id]
    # ]

    conflict_opts = [on_conflict: :replace_all, conflict_target: [:match_id]]

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:timeslot, changeset, conflict_opts)
    |> Oban.insert(:push, push_job)
    |> Repo.transaction()
    |> notify_subscribers([:timeslot, :offered, mate])
  end

  # TODO delete stale slots
  # can list where I'm picker, where I'm not picker, where slot is selected
  def list_relevant_slots(user_id) do
    my_matches =
      Match
      |> where([m], m.user_id_1 == ^user_id or m.user_id_2 == ^user_id)

    Timeslot
    |> join(:inner, [t], m in subquery(my_matches), on: t.match_id == m.id)
    |> select([t], %Timeslot{t | seen?: coalesce(t.seen?, false)})
    |> Repo.all()
    |> postprocess_seen(user_id)
  end

  defp postprocess_seen(timeslots, user_id) do
    Enum.map(timeslots, fn timeslot ->
      %Timeslot{picker_id: picker_id, seen?: seen?, selected_slot: selected_slot} = timeslot

      seen? =
        cond do
          # slot is picked
          selected_slot ->
            # if our user is the picker -> they've seen it
            # otherwise we look into :seen?
            picker_id == user_id || seen?

          # no slot is picked, and our user is picker
          picker_id == user_id ->
            # we look into `:seen?`
            seen?

          # no slot is picked, and our user is not picker
          # -> they've offered the slot, so they've seen it
          true ->
            true
        end

      %Timeslot{timeslot | seen?: seen?}
    end)
  end

  @spec mark_timeslot_seen_or_delete_expired(Ecto.UUID.t(), keyword) :: :deleted | :seen | false
  @doc "mark_timeslot_seen_or_delete_expired(<match-id>, by: <user-id>)"
  def mark_timeslot_seen_or_delete_expired(match_id, opts) do
    by_user_id = Keyword.fetch!(opts, :by)
    reference = opts[:reference] || DateTime.utc_now()

    {:ok, result} =
      Repo.transact(fn ->
        timeslot = Repo.get_by!(Timeslot, match_id: match_id)

        result =
          if expired?(timeslot, reference) do
            if timeslot.picker_id == by_user_id do
              delete_expired_timeslot(match_id, reference) && :deleted
            end || false
          else
            mark_timeslot_seen(match_id, by_user_id) && :seen
          end

        {:ok, result}
      end)

    result
  end

  defp expired?(%Timeslot{selected_slot: nil, slots: slots}, reference) do
    filter_valid_slots(slots, reference) == []
  end

  defp expired?(%Timeslot{selected_slot: selected_slot}, reference) do
    not future_slot?(selected_slot, reference)
  end

  defp mark_timeslot_seen(match_id, by_user_id) do
    {count, _} =
      Timeslot
      |> where(match_id: ^match_id)
      # TODO refactor rename picker -> actor and set it to offerer after slot is picked and use it here
      # if no selected slot -> picker can mark as seen
      # otherwise it's offerer who can mark as seen
      |> where(
        [t],
        fragment(
          "case when ? is null then ? = ? else ? != ? end",
          t.selected_slot,
          t.picker_id,
          type(^by_user_id, Ecto.UUID),
          t.picker_id,
          type(^by_user_id, Ecto.UUID)
        )
      )
      |> Repo.update_all(set: [seen?: true])

    count == 1
  end

  defp delete_expired_timeslot(match_id, _reference) do
    {count, _} =
      Timeslot
      |> where(match_id: ^match_id)
      # |> where(expired)
      |> Repo.delete_all([])

    count == 1
  end

  @doc "accept_slot(timestamp, match: <match_id>, picker: <user_id>)"
  def accept_slot(slot, opts) do
    reference = prev_slot(opts[:reference] || DateTime.utc_now())
    {:ok, slot, 0} = DateTime.from_iso8601(slot)
    true = DateTime.compare(slot, reference) in [:eq, :gt]

    match_id = Keyword.fetch!(opts, :match)
    picker = Keyword.fetch!(opts, :picker)

    %Match{id: match_id, user_id_1: uid1, user_id_2: uid2} = get_match_for_user(match_id, picker)
    [mate] = [uid1, uid2] -- [picker]

    Bot.async_post_silent_message(
      "accepting slot for match #{match_id} (users #{uid1}, #{uid2}) by #{picker}: #{inspect(slot)}"
    )

    {1, [timeslot]} =
      Timeslot
      |> where(match_id: ^match_id)
      |> where(picker_id: ^picker)
      |> where([t], ^slot in t.slots)
      |> select([t], t)
      |> Repo.update_all(set: [selected_slot: slot, seen?: false])

    accepted_push =
      PushNotifications.DispatchJob.new(%{
        "type" => "timeslot_accepted",
        "match_id" => match_id,
        "receiver_id" => mate
      })

    reminder_push =
      PushNotifications.DispatchJob.new(
        %{
          "type" => "timeslot_reminder",
          "match_id" => match_id,
          "slot" => slot
        },
        scheduled_at: DateTime.add(slot, -15 * 60, :second)
      )

    started_push =
      PushNotifications.DispatchJob.new(
        %{
          "type" => "timeslot_started",
          "match_id" => match_id,
          "slot" => slot
        },
        scheduled_at: slot
      )

    Oban.insert_all([accepted_push, reminder_push, started_push])
    notify_subscribers({:ok, timeslot}, [:timeslot, :accepted, mate])
  end

  @doc "cancel_slot(<match-id>, by: <user-id>)"
  def cancel_slot(match_id, opts) do
    by_user_id = Keyword.fetch!(opts, :by)

    %Match{id: match_id, user_id_1: uid1, user_id_2: uid2} =
      get_match_for_user(match_id, by_user_id)

    [mate] = [uid1, uid2] -- [by_user_id]

    Bot.async_post_silent_message(
      "cancelling timeslot for match #{match_id} (users #{uid1}, #{uid2}) by #{by_user_id}"
    )

    {1, [%Timeslot{selected_slot: selected_slot} = timeslot]} =
      Timeslot
      |> where(match_id: ^match_id)
      # |> where([t], t.picker_id in ^[])
      |> select([t], t)
      |> Repo.delete_all()

    if selected_slot do
      push =
        PushNotifications.DispatchJob.new(%{
          "type" => "timeslot_cancelled",
          "match_id" => match_id
        })

      Oban.insert_all([push])
    end

    notify_subscribers({:ok, timeslot}, [:timeslot, :cancelled, mate])

    :ok
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
    DateTime.compare(datetime, reference) in [:eq, :gt]
  end

  # ~U[2021-03-23 14:12:00Z] -> ~U[2021-03-23 14:00:00Z]
  # ~U[2021-03-23 14:49:00Z] -> ~U[2021-03-23 14:45:00Z]
  defp prev_slot(%DateTime{minute: minutes} = dt) do
    %DateTime{dt | minute: div(minutes, 15) * 15, second: 0, microsecond: {0, 0}}
  end

  def notify_timeslot_started(match) do
    %Match{id: match_id, user_id_1: uid1, user_id_2: uid2} = match

    for uid <- [uid1, uid2] do
      Phoenix.PubSub.broadcast(
        @pubsub,
        pubsub_user_topic(uid),
        {__MODULE__, [:timeslot, :started], match_id}
      )
    end
  end

  def notify_timeslot_ended(match) do
    %Match{id: match_id, user_id_1: uid1, user_id_2: uid2} = match

    for uid <- [uid1, uid2] do
      Phoenix.PubSub.broadcast(
        @pubsub,
        pubsub_user_topic(uid),
        {__MODULE__, [:timeslot, :ended], match_id}
      )
    end
  end

  def schedule_timeslot_ended(match, timeslot) do
    ended_at = DateTime.add(timeslot.selected_slot, 15 * 60, :second)

    job =
      PushNotifications.DispatchJob.new(
        %{"type" => "timeslot_ended", "match_id" => match.id},
        scheduled_at: ended_at
      )

    Oban.insert!(job)
  end

  ######################### CALLS #########################

  def pushkit_call_mate(%Profile{user_id: caller_id, name: caller_name}, mate_id) do
    Bot.async_post_silent_message("#{caller_id} (#{caller_name}) calls #{mate_id}")

    mate_id
    |> Accounts.list_pushkit_devices()
    |> PushNotifications.APNS.pushkit_call(%{"user_id" => caller_id, "name" => caller_name})
    |> List.flatten()
    |> case do
      [%Pigeon.APNS.Notification{response: :success}] -> true
      [_, _] -> false
      [] -> false
    end
  end

  ######################## UNMATCH ########################

  @doc "unmatch(user: <uuid>, match: <uuid>)"
  def unmatch(params) do
    user_id = Keyword.fetch!(params, :user)
    match_id = Keyword.fetch!(params, :match)

    Bot.async_post_silent_message("#{user_id} unmatches match-id=#{match_id}")

    Ecto.Multi.new()
    |> Ecto.Multi.run(:unmatch, fn _repo, _changes ->
      Match
      |> where(id: ^match_id)
      |> where([m], m.user_id_1 == ^user_id or m.user_id_2 == ^user_id)
      |> select([m], [m.user_id_1, m.user_id_2])
      |> Repo.delete_all()
      |> case do
        {1, [user_ids]} -> {:ok, user_ids}
        {0, _} -> {:error, :match_not_found}
      end
    end)
    |> Ecto.Multi.run(:delete_likes, fn _repo, %{unmatch: [uid1, uid2]} ->
      {count, _} =
        ProfileLike
        |> where([l], l.by_user_id == ^uid1 and l.user_id == ^uid2)
        |> or_where([l], l.by_user_id == ^uid2 and l.user_id == ^uid1)
        |> Repo.delete_all()

      {:ok, count}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{unmatch: user_ids}} -> {:ok, user_ids}
      {:error, :unmatch, reason, _changes} -> {:error, reason}
    end
    |> notify_subscribers([:unmatched, match_id])
  end

  #################### HELPERS ####################

  def get_current_matches(user_id) do
    seen = SeenMatch |> where(by_user_id: ^user_id)

    Match
    |> where([m], m.user_id_1 == ^user_id or m.user_id_2 == ^user_id)
    |> join(:left, [m], s in subquery(seen), on: m.id == s.match_id)
    |> select([m, s], %Match{m | seen?: not is_nil(s.match_id)})
    |> Repo.all()
    |> preload_match_profiles(user_id)
    |> with_timeslots(user_id)
  end

  # TODO broadcast
  @doc "mark_match_seen(<match-id>, by: <user-id>)"
  def mark_match_seen(match_id, opts) do
    by_user_id = Keyword.fetch!(opts, :by)

    %SeenMatch{by_user_id: by_user_id, match_id: match_id}
    |> change()
    |> unique_constraint(:seen, name: :seen_matches_pkey)
    |> Repo.insert()
  end

  def get_match_for_user(match_id, user_id) do
    Match
    |> where(id: ^match_id)
    |> where([m], m.user_id_1 == ^user_id or m.user_id_2 == ^user_id)
    |> Repo.one!()
    |> preload_mate(user_id)
  end

  defp preload_mate(match, user_id) do
    [mate_id] = [match.user_id_1, match.user_id_2] -- [user_id]
    mate = Repo.get!(Profile, mate_id)
    %Match{match | profile: mate}
  end

  # TODO cleanup
  defp preload_match_profiles(matches, user_id) do
    mate_matches =
      Map.new(matches, fn match ->
        [mate_id] = [match.user_id_1, match.user_id_2] -- [user_id]
        {mate_id, match}
      end)

    mates = Map.keys(mate_matches)

    Profile
    |> where([p], p.user_id in ^mates)
    |> Repo.all()
    |> Enum.map(fn mate ->
      match = Map.fetch!(mate_matches, mate.user_id)
      %Match{match | profile: mate}
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

  ###################### YO ######################

  alias PushNotifications.APNS
  alias Pigeon.APNS.Notification

  @doc "send_yo(match: match_id, from: user_id)"
  def send_yo(opts) do
    from = Keyword.fetch!(opts, :from)
    match = Keyword.fetch!(opts, :match)

    match =
      Match
      |> where(id: ^match)
      |> where([m], ^from == m.user_id_1 or ^from == m.user_id_2)
      |> Repo.one()

    if match do
      %Match{user_id_1: uid1, user_id_2: uid2} = match
      [mate_id] = [uid1, uid2] -- [from]
      {sender_name, sender_gender} = profile_info(from)
      apns_devices = Accounts.list_apns_devices(mate_id)

      sender = sender_name || dgettext("yo", "Кто-то там")
      title = dgettext("yo", "%{sender} зовёт тебя пообщаться!", sender: sender)
      body = dgettext("yo", "Не упусти момент 😼")
      message = [title, body]
      ack_id = Ecto.UUID.generate()

      Task.Supervisor.start_child(
        Yo.task_sup(),
        fn ->
          Phoenix.PubSub.subscribe(T.PubSub, "yo_ack:#{ack_id}")

          apns_devices
          |> Enum.map(fn %{device_id: device_id, locale: locale} ->
            device_id = Base.encode16(device_id)

            Gettext.with_locale(locale, fn ->
              build_yo_notification(device_id, message, ack_id)
            end)
          end)
          |> Enum.map(&APNS.push_all_envs/1)
          |> List.flatten()
          |> Enum.reduce([], fn %Notification{response: r, device_token: device_id} = n, acc ->
            if r in [:bad_device_token, :unregistered] do
              T.Accounts.remove_apns_device(device_id)
            end

            if r == :success do
              [n | acc]
            else
              acc
            end
          end)
          |> case do
            [] = _no_success ->
              send_yo_sms(mate_id, sender_name, sender_gender)

            [_ | _] = _at_least_one ->
              receive do
                :ack -> :ok
              after
                :timer.seconds(5) ->
                  send_yo_sms(mate_id, sender_name, sender_gender)
              end
          end
        end,
        # TODO maybe just spawn?
        shutdown: :timer.minutes(1)
      )

      ack_id
    end
  end

  def ack_yo(ack_id) do
    Phoenix.PubSub.broadcast!(T.PubSub, "yo_ack:#{ack_id}", :ack)
  end

  def send_yo_sms(user_id, sender_name, sender_gender) do
    phone_number = Accounts.get_phone_number!(user_id)
    locale = if String.starts_with?(phone_number, "+7"), do: "ru", else: "en"

    message =
      Gettext.with_locale(locale, fn ->
        yo_sms_message(sender_name, sender_gender)
      end)

    T.SMS.deliver(phone_number, message)
  end

  defp yo_sms_message(sender_name, sender_gender) do
    sender_name = sender_name || dgettext("yo", "Кто-то там")
    sender_gender = render_gender(sender_gender)

    dgettext(
      "yo",
      """
      Since: %{sender_name} зовёт тебя пообщаться!
      Не упусти момент, пока %{sender_gender} онлайн 😼
      Заходи в Since
      """,
      sender_name: sender_name,
      sender_gender: sender_gender
    )
  end

  defp render_gender("F"), do: dgettext("yo", "она")
  defp render_gender("M"), do: dgettext("yo", "он")
  defp render_gender(_it), do: dgettext("yo", "оно")

  defp build_yo_notification(device_id, [title, body], ack_id) do
    APNS.build_notification("yo", device_id, %{
      "ack_id" => ack_id,
      "title" => title,
      "body" => body
    })
  end

  def profile_info(user_id) do
    Profile
    |> where(user_id: ^user_id)
    |> select([p], {p.name, p.gender})
    |> Repo.one!()
  end

  ###################### MESSAGES ######################

  # TODO check user is match member
  # or use rls
  def add_message(match_id, user_id, attrs) do
    changeset =
      message_changeset(
        %Message{id: Ecto.Bigflake.UUID.autogenerate(), author_id: user_id, match_id: match_id},
        attrs
      )

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:message, changeset)
    |> Oban.insert(:push_notification, fn %{message: message} ->
      PushNotifications.DispatchJob.new(%{
        "type" => "message",
        "author_id" => message.author_id,
        "match_id" => match_id
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{message: message}} -> {:ok, message}
      {:error, :message, %Ecto.Changeset{} = changeset, _changes} -> {:error, changeset}
    end

    # |> notify_subscribers([:message, :created])
  end

  def media_upload_form(content_type) do
    Media.sign_form_upload(
      key: Ecto.UUID.generate(),
      content_type: content_type,
      max_file_size: 8_000_000,
      expires_in: :timer.hours(1)
    )
  end

  def media_s3_url do
    Media.user_s3_url()
  end

  # TODO rls or auth
  # TODO paginate
  def list_messages(match_id, opts \\ []) do
    # dir = opts[:dir] || :asc
    # limit = ensure_valid_limit(opts[:limit]) || 20

    q =
      Message
      |> where(match_id: ^match_id)
      |> order_by([m], asc: m.id)

    # |> limit(^limit)
    # |> paginate(opts)
    # |> Repo.all()

    q =
      if after_id = opts[:after] do
        where(q, [m], m.id > ^after_id)
      else
        q
      end

    Repo.all(q)
  end

  # TODO do it proper
  # defp paginate(query, opts) do
  #   case {opts[:after], opts[:before]} do
  #     {nil, nil} ->
  #       query

  #     {after_timestamp, nil} ->
  #       paginate_after(query, after_timestamp)

  #     {nil, before_timestamp} ->
  #       paginate_before(query, before_timestamp)

  #     {after_timestamp, before_timestamp} ->
  #       query |> paginate_after(after_timestamp) |> paginate_before(before_timestamp)
  #   end
  # end

  # defp paginate_after(query, after_timestamp) do
  #   where(query, [m], m.timestamp >= ^after_timestamp)
  # end

  # defp paginate_before(query, before_timestamp) do
  #   where(query, [m], m.timestamp <= ^before_timestamp)
  # end

  # defp ensure_valid_limit(limit) when is_integer(limit) and limit > 0 and limit <= 100 do
  #   limit
  # end

  # defp ensure_valid_limit(_invalid), do: nil

  import Ecto.Changeset

  @texts ["text", "markdown", "emoji"]
  @media ["audio", "photo", "video"]
  @valid_kinds @texts ++ @media ++ ["location"]

  def message_changeset(changeset, attrs) do
    changeset
    |> cast(attrs, [:kind, :data])
    |> validate_required([:kind, :data])
    |> validate_inclusion(:kind, @valid_kinds)
    |> validate_message_data()
  end

  defp validate_message_data(%Ecto.Changeset{valid?: true} = changeset) do
    case get_field(changeset, :kind) do
      t when t in @texts -> validate_text_message(changeset)
      m when m in @media -> validate_media_message(changeset)
      "location" -> validate_location_message(changeset)
    end
  end

  defp validate_message_data(changeset), do: changeset

  defp validate_text_message(changeset) do
    data = get_field(changeset, :data) || %{}

    %Message.Text{}
    |> cast(data, [:text])
    |> validate_required(:text)
    |> validate_length(:text, min: 1, max: 1000, count: :bytes)
    |> maybe_merge_errors(changeset)
  end

  defp validate_media_message(changeset) do
    data = get_field(changeset, :data) || %{}

    %Message.Media{}
    |> cast(data, [:s3_key])
    |> validate_required(:s3_key)
    |> validate_length(:s3_key, min: 1, max: 100, count: :bytes)
    |> maybe_merge_errors(changeset)
  end

  defp validate_location_message(changeset) do
    data = get_field(changeset, :data) || %{}

    %Message.Location{}
    |> cast(data, [:lat, :lon])
    |> validate_required([:lat, :lon])
    |> maybe_merge_errors(changeset)
  end

  defp maybe_merge_errors(%Ecto.Changeset{valid?: true}, changeset) do
    changeset
  end

  defp maybe_merge_errors(%Ecto.Changeset{valid?: false} = changeset2, changeset1) do
    merge_errors(changeset1, changeset2)
  end

  defp merge_errors(changeset1, changeset2) do
    %Ecto.Changeset{
      changeset1
      | valid?: false,
        errors: Keyword.merge(changeset1.errors, changeset2.errors)
    }
  end
end
