defmodule T.Calls do
  @moduledoc false
  import Ecto.Query
  alias Ecto.Multi

  require Logger

  alias T.{Repo, Twilio, Accounts, Feeds}
  alias T.Calls.Call
  alias T.Feeds.{FeedProfile}
  alias T.Matches.{Match, MatchEvent}
  alias T.PushNotifications.APNS
  alias T.Bot

  @type uuid :: Ecto.Bigflake.UUID.t()

  @spec ice_servers :: [map]
  def ice_servers do
    Twilio.ice_servers()
  end

  @spec call(uuid, uuid, DateTime.t()) :: {:ok, call_id :: uuid} | {:error, reason :: String.t()}
  def call(caller_id, called_id, reference \\ DateTime.utc_now()) do
    call_id = Ecto.Bigflake.UUID.generate()

    with :ok <- ensure_call_allowed(caller_id, called_id, reference),
         {:ok, devices} <- ensure_has_devices(called_id),
         :ok <- push_call(caller_id, call_id, devices) do
      %Call{id: ^call_id} =
        Repo.insert!(%Call{id: call_id, caller_id: caller_id, called_id: called_id})

      m =
        "call attempt #{fetch_name(caller_id)} (#{caller_id}) calling #{fetch_name(called_id)} (#{called_id})"

      Logger.warn(m)
      Bot.async_post_message(m)

      {:ok, call_id}
    end
  end

  @spec ensure_call_allowed(uuid, uuid, DateTime.t()) :: :ok | {:error, reason :: String.t()}
  defp ensure_call_allowed(caller_id, called_id, reference) do
    cond do
      TWeb.CallTracker.in_call?(called_id) -> {:error, "receiver is busy"}
      missed?(called_id, caller_id) -> :ok
      matched?(caller_id, called_id) -> :ok
      in_live_mode?(caller_id, called_id, reference) -> :ok
      true -> {:error, "call not allowed"}
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

  @spec in_live_mode?(uuid, uuid, DateTime.t()) :: boolean
  defp in_live_mode?(caller_id, called_id, reference) do
    Feeds.live_now?(caller_id, reference) and Feeds.live_now?(called_id, reference)
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

  defp set_call_accepted_at(multi, call_id, now) do
    Multi.run(multi, :call, fn _repo, _changes ->
      {1, [call]} =
        Call
        |> where(id: ^call_id)
        |> select([p], {p.caller_id, p.called_id})
        |> Repo.update_all(set: [accepted_at: now])

      {:ok, call}
    end)
  end

  defp maybe_get_match_id(multi) do
    Multi.run(multi, :match_id, fn _repo, %{call: {caller, called}} ->
      match_id =
        Match
        |> where([m], m.user_id_1 == ^caller and m.user_id_2 == ^called)
        |> or_where([m], m.user_id_1 == ^called and m.user_id_2 == ^caller)
        |> order_by(desc: :inserted_at)
        |> limit(1)
        |> select([m], m.id)
        |> Repo.one()

      {:ok, match_id}
    end)
  end

  defp maybe_insert_call_start_event(multi) do
    Multi.run(multi, :event, fn _repo, %{match_id: match_id} ->
      if match_id do
        Repo.insert(%MatchEvent{
          timestamp: DateTime.truncate(DateTime.utc_now(), :second),
          match_id: match_id,
          event: "call_start"
        })
      else
        {:ok, nil}
      end
    end)
  end

  # TODO not ignore errors (currently always :ok)
  @spec accept_call(uuid, DateTime.t()) :: :ok
  def accept_call(call_id, now \\ utc_now()) do
    Multi.new()
    |> set_call_accepted_at(call_id, now)
    |> maybe_get_match_id()
    |> maybe_insert_call_start_event()
    |> Repo.transaction()
    |> case do
      {:ok, %{call: {caller, called}, match_id: match_id}} = success ->
        if match_id do
          selected_slot =
            T.Matches.Timeslot
            |> where(match_id: ^match_id)
            |> select([t], t.selected_slot)
            |> Repo.one()

          if selected_slot do
            seconds = DateTime.utc_now() |> DateTime.diff(selected_slot)
            minutes = div(seconds, 60)

            m =
              "call starts #{fetch_name(caller)} (#{caller}) with #{fetch_name(called)} (#{called}), #{minutes}m later than agreed slot"

            Logger.warn(m)
            Bot.async_post_message(m)
          end

          T.Matches.notify_match_expiration_reset(match_id, [caller, called])
        else
          m =
            "LIVE call starts #{fetch_name(caller)} (#{caller}) with #{fetch_name(called)} (#{called})"

          Logger.warn(m)
          Bot.async_post_message(m)
        end

        success

      {:error, _step, _reason, _changes} = failure ->
        failure
    end

    :ok
  end

  @spec end_call(uuid, uuid, DateTime.t()) :: :ok
  def end_call(user_id, call_id, now \\ utc_now()) do
    {1, [call]} =
      Call
      |> where(id: ^call_id)
      |> select([c], c)
      |> Repo.update_all(set: [ended_at: now, ended_by: user_id])

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

  def list_live_missed_calls_with_profile(user_id, reference) do
    Call
    |> where(called_id: ^user_id)
    # call hasn't been picked up
    |> where([c], is_nil(c.accepted_at))
    |> where([c], c.inserted_at > ^reference)
    |> order_by(asc: :id)
    |> join(:inner, [c], p in FeedProfile, on: c.caller_id == p.user_id)
    |> select([c, p], {c, p})
    |> Repo.all()
  end
end
