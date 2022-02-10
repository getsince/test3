defmodule T.Calls do
  @moduledoc false
  import Ecto.Query
  alias Ecto.Multi

  require Logger

  alias T.{Repo, Twilio, Accounts, Feeds, Matches}
  alias T.Calls.{Call, Voicemail}
  alias T.Feeds.{FeedProfile}
  alias T.Matches.{Match, MatchEvent, ArchivedMatch, Interaction}
  alias T.PushNotifications.{APNS, DispatchJob}
  alias T.Bot

  @type uuid :: Ecto.Bigflake.UUID.t()

  @spec ice_servers :: [map]
  def ice_servers do
    Twilio.ice_servers()
  end

  @spec call(uuid, uuid) :: {:ok, call_id :: uuid} | {:error, reason :: String.t()}
  def call(caller_id, called_id) do
    call_id = Ecto.Bigflake.UUID.generate()
    call = %Call{id: call_id, caller_id: caller_id, called_id: called_id}

    interaction =
      if match_id = match_id(caller_id, called_id) do
        %Interaction{
          id: call_id,
          match_id: match_id,
          from_user_id: caller_id,
          to_user_id: called_id,
          data: %{"type" => "call"}
        }
      end

    with :ok <- ensure_call_allowed(caller_id, called_id),
         {:ok, devices} <- ensure_has_devices(called_id),
         :ok <- push_call(caller_id, call_id, devices) do
      {:ok, interaction} =
        Repo.transaction(fn ->
          Repo.insert!(call)
          if interaction, do: Repo.insert!(interaction)
        end)

      if interaction do
        Matches.broadcast_interaction(interaction)
      end

      m =
        "call attempt #{fetch_name(caller_id)} (#{caller_id}) calling #{fetch_name(called_id)} (#{called_id})"

      Logger.warn(m)
      Bot.async_post_message(m)

      {:ok, call_id}
    end
  end

  @spec ensure_call_allowed(uuid, uuid) :: :ok | {:error, reason :: String.t()}
  defp ensure_call_allowed(caller_id, called_id) do
    cond do
      # TWeb.CallTracker.in_call?(called_id) -> {:error, "receiver is busy"}
      missed?(called_id, caller_id) ->
        :ok

      matched?(caller_id, called_id) ->
        :ok

      true ->
        {:error, "call not allowed"}
    end
  end

  @spec missed?(uuid, uuid) :: boolean
  defp missed?(caller_id, called_id) do
    Call
    |> where(caller_id: ^caller_id)
    |> where(called_id: ^called_id)
    |> where([c], is_nil(c.accepted_at) and not is_nil(c.ended_at))
    |> Repo.exists?()
  end

  @spec matched?(uuid, uuid) :: boolean
  defp matched?(caller_id, called_id) do
    [user_id_1, user_id_2] = Enum.sort([caller_id, called_id])

    Match
    |> where(user_id_1: ^user_id_1)
    |> where(user_id_2: ^user_id_2)
    |> Repo.exists?()
  end

  @spec match_id(uuid, uuid) :: uuid | nil
  defp match_id(caller_id, called_id) do
    [user_id_1, user_id_2] = Enum.sort([caller_id, called_id])

    Match
    |> where(user_id_1: ^user_id_1)
    |> where(user_id_2: ^user_id_2)
    |> select([m], m.id)
    |> Repo.one()
  end

  @spec ensure_has_devices(uuid) ::
          {:ok, [%Accounts.PushKitDevice{}]} | {:error, reason :: String.t()}
  defp ensure_has_devices(user_id) do
    case Accounts.list_pushkit_devices(user_id) do
      [_ | _] = devices -> {:ok, devices}
      [] -> {:error, "no pushkit devices available"}
    end
  end

  @spec push_call(uuid, uuid, [%Accounts.PushKitDevice{}]) :: :ok | {:error, reason :: String.t()}
  defp push_call(caller_id, call_id, devices) do
    caller_name = fetch_name(caller_id)
    payload = %{"caller_id" => caller_id, "call_id" => call_id, "caller_name" => caller_name}

    push_sent? =
      devices
      |> APNS.pushkit_call(payload)
      |> Enum.any?(fn response -> response == :ok end)

    if push_sent?, do: :ok, else: {:error, "all pushes failed"}
  end

  @spec fetch_name(Ecto.UUID.t()) :: String.t()
  defp fetch_name(user_id) do
    FeedProfile
    |> where(user_id: ^user_id)
    |> select([p], p.name)
    |> Repo.one!()
  end

  @spec get_call_role_and_peer(uuid, uuid) ::
          {:ok, :caller | :called, %FeedProfile{}} | {:error, :not_found | :ended}
  def get_call_role_and_peer(call_id, user_id) do
    Call
    |> where(id: ^call_id)
    |> where([c], c.caller_id == ^user_id or c.called_id == ^user_id)
    |> Repo.one()
    |> case do
      %Call{ended_at: %DateTime{}} -> {:error, :ended}
      %Call{caller_id: ^user_id, called_id: peer_id} -> {:ok, :caller, fetch_profile(peer_id)}
      %Call{called_id: ^user_id, caller_id: peer_id} -> {:ok, :called, fetch_profile(peer_id)}
      nil -> {:error, :not_found}
    end
  end

  defp utc_now do
    DateTime.truncate(DateTime.utc_now(), :second)
  end

  defp update_call_m(multi, call_id, updates) do
    call_q = Call |> where(id: ^call_id) |> select([c], c)
    Multi.update_all(multi, :call, call_q, updates)
  end

  defp get_match_id_m(multi) do
    Multi.run(multi, :match_id, fn _repo, %{call: {1, [call]}} ->
      %Call{caller_id: caller, called_id: called} = call

      match_id =
        Match
        |> where([m], m.user_id_1 == ^caller and m.user_id_2 == ^called)
        |> or_where([m], m.user_id_1 == ^called and m.user_id_2 == ^caller)
        |> select([m], m.id)
        |> Repo.one()

      {:ok, match_id}
    end)
  end

  defp maybe_insert_call_start_event_m(multi, now) do
    Multi.run(multi, :event, fn _repo, %{match_id: match_id} ->
      if match_id do
        event = %MatchEvent{timestamp: now, match_id: match_id, event: "call_start"}
        Repo.insert(event)
      else
        {:ok, nil}
      end
    end)
  end

  defmacrop jsonb_maybe_put(target, key, value) do
    quote do
      fragment(
        "jsonb_set_lax(?, ?, ?, true, 'return_target')",
        unquote(target),
        unquote([key]),
        unquote(value)
      )
    end
  end

  defp update_call_interaction_m(multi) do
    interaction = fn %{call: call_update} ->
      {1, [%Call{id: call_id, accepted_at: accepted_at, ended_at: ended_at}]} = call_update

      Interaction
      |> where(id: ^call_id)
      |> select([i], i)
      |> update([i],
        set: [
          data:
            i.data
            |> jsonb_maybe_put("accepted_at", ^accepted_at)
            |> jsonb_maybe_put("ended_at", ^ended_at)
        ]
      )
    end

    Multi.update_all(multi, :interaction, interaction, _updates = [])
  end

  # TODO not ignore errors (currently always :ok)
  @spec accept_call(uuid, DateTime.t()) :: :ok
  def accept_call(call_id, now \\ utc_now()) do
    Multi.new()
    |> update_call_m(call_id, set: [accepted_at: now])
    |> get_match_id_m()
    |> maybe_insert_call_start_event_m(now)
    |> update_call_interaction_m()
    |> Repo.transaction()
    |> tap(fn
      {:ok, changes} = success ->
        %{call: {1, [call]}, match_id: match_id, interaction: interaction_update} = changes
        %Call{caller_id: caller, called_id: called} = call

        interaction =
          case interaction_update do
            {1, [interaction]} -> interaction
            {0, _} -> nil
          end

        if interaction do
          Matches.broadcast_interaction(interaction)
        end

        selected_slot =
          Matches.Timeslot
          |> where(match_id: ^match_id)
          |> select([t], t.selected_slot)
          |> Repo.one()

        if selected_slot do
          seconds = DateTime.diff(now, selected_slot)
          minutes = div(seconds, 60)

          m =
            "call starts #{fetch_name(caller)} (#{caller}) with #{fetch_name(called)} (#{called}), #{minutes}m later than agreed slot"

          Logger.warn(m)
          Bot.async_post_message(m)
        end

        Matches.notify_match_expiration_reset(match_id, [caller, called])

        success

      {:error, _step, _reason, _changes} = failure ->
        failure
    end)

    :ok
  end

  @spec end_call(uuid, uuid, DateTime.t()) :: :ok
  def end_call(user_id, call_id, now \\ utc_now()) do
    Multi.new()
    |> update_call_m(call_id, set: [ended_at: now, ended_by: user_id])
    |> get_match_id_m()
    |> update_call_interaction_m()
    |> Repo.transaction()
    |> tap(fn
      {:ok, changes} ->
        %{call: {1, [call]}, interaction: interaction_update} = changes

        interaction =
          case interaction_update do
            {1, [interaction]} -> interaction
            {0, _} -> nil
          end

        if interaction do
          Matches.broadcast_interaction(interaction)
        end

        {user_status, second_user} =
          if user_id == call.caller_id do
            {"caller", call.called_id}
          else
            {"receiver", call.caller_id}
          end

        m =
          if call.accepted_at do
            seconds = call.ended_at |> DateTime.diff(call.accepted_at)
            minutes = div(seconds, 60)

            "call ends #{fetch_name(user_id)} (#{user_id}, #{user_status}) ended a call with #{fetch_name(second_user)} (#{second_user}), call lasted for #{minutes}m"
          else
            "user #{fetch_name(user_id)} (#{user_id}, #{user_status}) ended a call with #{fetch_name(second_user)} (#{second_user}), call didn't happen"
          end

        Logger.warn(m)
        Bot.async_post_message(m)
    end)

    :ok
  end

  @spec fetch_profile(uuid) :: %FeedProfile{}
  defp fetch_profile(user_id) do
    FeedProfile
    |> where(user_id: ^user_id)
    |> Repo.one!()
  end

  @spec list_missed_calls_with_profile(uuid, Keyword.t()) :: [{%Call{}, %FeedProfile{} | nil}]
  def list_missed_calls_with_profile(user_id, opts) do
    missed_calls_q(user_id, opts)
    |> join(:inner, [c], p in FeedProfile, on: c.caller_id == p.user_id)
    |> select([c, p], {c, p})
    |> Repo.all()
  end

  @spec missed_calls_q(uuid, Keyword.t()) :: Ecto.Query.t()
  defp missed_calls_q(user_id, opts) do
    Call
    |> where(called_id: ^user_id)
    # call hasn't been picked up
    |> where([c], is_nil(c.accepted_at))
    # and call hasn't been declined
    |> where([c], is_nil(c.ended_by) or c.ended_by != c.called_id)
    |> order_by(asc: :id)
    |> maybe_after_missed_calls(opts[:after])
  end

  defp maybe_after_missed_calls(query, nil), do: query
  defp maybe_after_missed_calls(query, after_id), do: where(query, [c], c.id > ^after_id)

  alias T.Media

  def voicemail_s3_url do
    Media.user_s3_url()
  end

  def voicemail_url(s3_key) do
    Media.user_presigned_url(s3_key)
  end

  def voicemail_upload_form(content_type) do
    Media.sign_form_upload(
      key: Ecto.UUID.generate(),
      content_type: content_type,
      # 50 MB
      max_file_size: 50_000_000,
      expires_in: :timer.hours(1),
      acl: "private"
    )
  end

  @spec voicemail_save_message(uuid, uuid, uuid) ::
          {:ok, %Voicemail{}} | {:error, reason :: String.t()}
  def voicemail_save_message(caller_id, match_id, s3_key) do
    voicemail = %Voicemail{caller_id: caller_id, match_id: match_id, s3_key: s3_key}

    Multi.new()
    |> Multi.run(:mate, fn _repo, _changes ->
      users =
        Match
        |> where(id: ^match_id)
        |> where([m], m.user_id_1 == ^caller_id or m.user_id_2 == ^caller_id)
        |> select([m], [m.user_id_1, m.user_id_2])
        |> Repo.one()

      if users do
        [mate] = users -- [caller_id]
        {:ok, mate}
      else
        {:error, :not_found}
      end
    end)
    |> Multi.run(:delete_voicemail, fn _repo, %{mate: mate} ->
      # TODO should still be deleted?
      {_, s3_keys} =
        Voicemail
        |> where(match_id: ^match_id)
        |> where(caller_id: ^mate)
        |> select([v], v.s3_key)
        |> Repo.delete_all()

      schedule_s3_delete(s3_keys)

      {:ok, s3_keys}
    end)
    |> Multi.insert(:voicemail, voicemail)
    |> Multi.insert(:interaction, fn %{mate: mate, voicemail: voicemail} ->
      %Interaction{
        id: voicemail.id,
        from_user_id: caller_id,
        to_user_id: mate,
        match_id: match_id,
        data: %{"type" => "voicemail", "s3" => s3_key}
      }
    end)
    |> Oban.insert(:push, fn %{mate: mate} ->
      DispatchJob.new(%{
        "type" => "voicemail_sent",
        "match_id" => match_id,
        "caller_id" => caller_id,
        "receiver_id" => mate
      })
    end)
    |> Multi.delete_all(:unarchive, where(ArchivedMatch, match_id: ^match_id))
    |> Repo.transaction()
    |> case do
      {:ok, %{voicemail: voicemail, interaction: interaction, mate: mate}} ->
        m =
          "voicemail from #{fetch_name(caller_id)} (#{caller_id}) to #{fetch_name(mate)} (#{mate})"

        Logger.warn(m)
        Bot.async_post_message(m)

        Feeds.broadcast_for_user(mate, {__MODULE__, [:voicemail, :received], voicemail})
        Matches.broadcast_interaction(interaction)
        {:ok, voicemail}

      {:error, :mate, :not_found, _changes} ->
        {:error, "voicemail not allowed"}
    end
  end

  @spec voicemail_listen_message(uuid, uuid, DateTime.t()) :: boolean()
  def voicemail_listen_message(user_id, voicemail_id, now \\ DateTime.utc_now()) do
    listened_at = DateTime.truncate(now, :second)

    {count, _} =
      Voicemail
      |> where(id: ^voicemail_id)
      |> join(:inner, [v], m in Match,
        on: m.id == v.match_id and (m.user_id_1 == ^user_id or m.user_id_2 == ^user_id)
      )
      |> where([v], v.caller_id != ^user_id)
      |> where([v, m], v.caller_id == m.user_id_1 or v.caller_id == m.user_id_2)
      |> Repo.update_all(set: [listened_at: listened_at])

    count == 1
  end

  @spec voicemail_delete_all(uuid) :: :ok
  def voicemail_delete_all(match_id) do
    {_count, s3_keys} =
      Voicemail
      |> where(match_id: ^match_id)
      |> select([v], v.s3_key)
      |> Repo.delete_all()

    schedule_s3_delete(s3_keys)

    :ok
  end

  defp schedule_s3_delete(s3_keys) do
    bucket = Media.user_bucket()

    s3_keys
    |> Enum.map(fn s3_key -> Media.S3DeleteJob.new(%{"bucket" => bucket, "s3_key" => s3_key}) end)
    |> Oban.insert_all()
  end
end
