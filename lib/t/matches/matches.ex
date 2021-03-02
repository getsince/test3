defmodule T.Matches do
  @moduledoc """
  User wants to fetch their active matches? Do they want to unmatch?
  Or maybe they want to send a message to their match?

  Then this is the palce to add code for it.
  """

  import Ecto.Query

  alias T.{Repo, Media, PushNotifications}
  alias T.Accounts.{User, Profile}
  alias T.Matches.{Match, Message, Yo}

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

  defp notify_subscribers({:ok, %{unmatch: user_ids}} = success, [:unmatched, match_id] = event) do
    msg = {__MODULE__, event, user_ids}
    Phoenix.PubSub.broadcast(@pubsub, pubsub_match_topic(match_id), msg)
    success
  end

  defp notify_subscribers({:ok, %{match: match}} = success, [:matched]) do
    if match do
      %Match{id: match_id, user_id_1: uid1, user_id_2: uid2, alive?: true} = match
      uids = Enum.map([uid1, uid2], &String.downcase/1)
      msg = {__MODULE__, [:matched, match_id], uids}

      for topic <- [pubsub_user_topic(uid1), pubsub_user_topic(uid2)] do
        Phoenix.PubSub.broadcast(@pubsub, topic, msg)
      end
    end

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
    |> maybe_hide_profiles([by_user_id, user_id])
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
      T.Feeds.ProfileLike
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
        Repo.insert(%Match{user_id_1: user_id_1, user_id_2: user_id_2, alive?: true})
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

  defp schedule_match_push(%Match{alive?: true, id: match_id}) do
    job = PushNotifications.DispatchJob.new(%{"type" => "match", "match_id" => match_id})
    Oban.insert(job)
  end

  # defp schedule_yo_push(%Match{alive?: true, id: match_id}, sender_id) do
  #   job =
  #     PushNotifications.DispatchJob.new(%{
  #       "type" => "yo",
  #       "match_id" => match_id,
  #       "sender_id" => sender_id
  #     })

  #   Oban.insert(job)
  # end

  defp maybe_hide_profiles(multi, user_ids) do
    Ecto.Multi.run(multi, :hide, fn _repo, %{match: match} ->
      hidden = if match, do: hide_profiles(user_ids)
      {:ok, hidden}
    end)
  end

  @doc false
  def hide_profiles(user_ids, max_match_count \\ 3) do
    profiles_with_match_count = profiles_with_match_count_q(user_ids)

    {_count, hidden} =
      Profile
      |> join(:inner, [p], c in subquery(profiles_with_match_count),
        on: c.count >= ^max_match_count and p.user_id == c.user_id
      )
      |> select([p], p.user_id)
      |> Repo.update_all(set: [hidden?: true])

    hidden
  end

  # TODO bench, ensure doesn't slow down with more unmatches
  defp profiles_with_match_count_q(user_ids) when is_list(user_ids) do
    Profile
    |> where([p], p.user_id in ^user_ids)
    |> join(:left, [p], m in Match, on: p.user_id in [m.user_id_1, m.user_id_2] and m.alive?)
    |> group_by([p], p.user_id)
    |> select([p, m], %{user_id: p.user_id, count: count(m.id)})
  end

  ######################## UNMATCH ########################

  defp unmatch(params) do
    user_id = Keyword.fetch!(params, :user)
    match_id = Keyword.fetch!(params, :match)

    Match
    |> where(id: ^match_id)
    |> where([m], m.user_id_1 == ^user_id or m.user_id_2 == ^user_id)
    |> where(alive?: true)
    |> update(set: [alive?: false])
    |> select([m], [m.user_id_1, m.user_id_2])
    |> Repo.update_all([])
    |> case do
      {1, [user_ids]} -> {:ok, user_ids}
      {0, _} -> {:error, :match_not_found}
    end
  end

  @spec unhide(user_ids :: [Ecto.UUID.t()]) :: unhidden_user_ids :: [Ecto.UUID.t()]
  defp unhide(user_ids) when is_list(user_ids) do
    Enum.reduce(user_ids, [], fn id, unhidden ->
      # TODO and if match count < 3
      if unhide_profile_if_not_blocked_or_deleted(id) do
        [id | unhidden]
      else
        unhidden
      end
    end)
  end

  @doc "unmatch_and_unhide(user: <uuid>, match: <uuid>)"
  def unmatch_and_unhide(params) do
    match_id = Keyword.fetch!(params, :match)

    Repo.transact(fn ->
      with {:ok, user_ids} <- unmatch(params),
           unhide <- unhide(user_ids),
           do: {:ok, %{unmatch: user_ids, unhide: unhide}}

      # TODO remove all scheduled notifications
    end)
    |> notify_subscribers([:unmatched, match_id])
  end

  defp unhide_profile_if_not_blocked_or_deleted(user_id) do
    not_blocked_or_deleted_user =
      User
      |> where([u], is_nil(u.blocked_at))
      |> where([u], is_nil(u.deleted_at))
      |> where(id: ^user_id)

    Profile
    |> where(user_id: ^user_id)
    |> join(:inner, [p], u in subquery(not_blocked_or_deleted_user), on: u.id == p.user_id)
    |> Repo.update_all(set: [hidden?: false])
    |> case do
      {1, nil} -> true
      {0, nil} -> false
    end
  end

  #################### HELPERS ####################

  def profiles_with_match_count(user_ids) do
    profiles_with_match_count_q(user_ids)
    |> Repo.all()
    |> Map.new(fn %{user_id: id, count: count} -> {id, count} end)
  end

  def get_current_matches(user_id) do
    Match
    |> where([m], m.user_id_1 == ^user_id or m.user_id_2 == ^user_id)
    |> where(alive?: true)
    |> Repo.all()
    |> preload_match_profiles(user_id)
  end

  def get_match_for_user(match_id, user_id) do
    Match
    |> where(id: ^match_id)
    |> where([m], m.user_id_1 == ^user_id or m.user_id_2 == ^user_id)
    |> where(alive?: true)
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

  ###################### YO ######################

  alias Pigeon.APNS
  alias Pigeon.APNS.Notification

  @doc "send_yo(match: match_id, from: user_id)"
  def send_yo(opts) do
    from = Keyword.fetch!(opts, :from)
    match = Keyword.fetch!(opts, :match)

    match =
      Match
      |> where(id: ^match)
      |> where([m], ^from == m.user_id_1 or ^from == m.user_id_2)
      |> where(alive?: true)
      |> Repo.one()

    if match do
      %Match{user_id_1: uid1, user_id_2: uid2} = match
      [mate_id] = [uid1, uid2] -- [from]
      sender_name = profile_name(from)
      raw_device_ids = device_ids(mate_id)

      title = "#{sender_name || "Кто-то там"} зовёт тебя пообщаться!"
      body = "Не упусти момент 😼"
      message = [title, body]
      ack_id = Ecto.UUID.generate()

      Task.Supervisor.start_child(
        Yo.task_sup(),
        fn ->
          Phoenix.PubSub.subscribe(T.PubSub, "yo_ack:#{ack_id}")

          raw_device_ids
          |> Enum.map(fn device_id ->
            device_id = Base.encode16(device_id)
            build_yo_notification(device_id, message, ack_id)
          end)
          |> APNS.push()
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
              send_yo_sms(mate_id, message)

            [_ | _] = _at_least_one ->
              receive do
                :ack -> :ok
              after
                :timer.seconds(5) ->
                  send_yo_sms(mate_id, message)
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

  def send_yo_sms(user_id, message) when is_list(message) do
    phone_number = T.Accounts.get_phone_number!(user_id)
    T.SMS.deliver(phone_number, "Since: " <> Enum.join(message, "\n"))
  end

  defp build_yo_notification(device_id, [title, body], ack_id) do
    base_notification(device_id, "yo")
    |> Notification.put_alert(%{"title" => title, "body" => body})
    |> Notification.put_badge(1)
    |> Notification.put_custom(%{"ack_id" => ack_id})
  end

  defp base_notification(device_id, collapse_id) do
    %Notification{
      device_token: device_id,
      topic: topic(),
      collapse_id: collapse_id
    }
  end

  defp topic do
    Application.fetch_env!(:pigeon, :apns)[:apns_default].topic
  end

  def profile_name(user_id) do
    Profile
    |> where(user_id: ^user_id)
    |> select([p], p.name)
    |> Repo.one!()
  end

  def device_ids(user_id) do
    T.Accounts.APNSDevice
    |> where(user_id: ^user_id)
    |> select([d], d.device_id)
    |> Repo.all()
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
    Media.s3_url()
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
