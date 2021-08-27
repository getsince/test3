defmodule T.Calls do
  @moduledoc false
  import Ecto.Query

  alias T.{Repo, Twilio, Accounts}
  alias T.Calls.Call
  alias T.Invites.CallInvite
  alias T.Feeds.{FeedProfile, ActiveSession}
  alias T.PushNotifications.APNS

  @spec ice_servers :: [map]
  def ice_servers do
    Twilio.ice_servers()
  end

  # TODO call match

  @spec call(Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, call_id :: Ecto.UUID.t()} | {:error, reason :: String.t()}
  def call(caller_id, called_id) do
    with {:allowed?, true} <- {:allowed?, call_allowed?(caller_id, called_id)},
         {:devices, [_ | _] = devices} <- {:devices, Accounts.list_pushkit_devices(called_id)},
         {:push, _any_push_sent? = true} <- {:push, push_call(caller_id, devices)} do
      %Call{id: call_id} = Repo.insert!(%Call{caller_id: caller_id, called_id: called_id})
      {:ok, call_id}
    else
      {:allowed?, false} -> {:error, "call not allowed"}
      {:devices, []} -> {:error, "no pushkit devices available"}
      {:push, false} -> {:error, "all pushes failed"}
    end
  end

  def call_allowed?(caller_id, called_id) do
    # call invites reference active sessions, so if it exists no need to check active session
    invited?(called_id, caller_id) or (active?(called_id) and missed?(called_id, caller_id))
  end

  defp active?(user_id) do
    ActiveSession
    |> where(user_id: ^user_id)
    |> Repo.exists?()
  end

  defp invited?(inviter_id, invited_id) do
    CallInvite
    |> where(by_user_id: ^inviter_id)
    |> where(user_id: ^invited_id)
    |> Repo.exists?()
  end

  defp missed?(caller_id, called_id) do
    Call
    |> where(caller_id: ^caller_id)
    |> where(called_id: ^called_id)
    |> where([c], is_nil(c.accepted_at) and not is_nil(c.ended_at))
    |> Repo.exists?()
  end

  @spec push_call(Ecto.UUID.t(), [%Accounts.PushKitDevice{}]) :: boolean
  def push_call(caller_id, devices) do
    alias Pigeon.APNS.Notification

    caller_name = fetch_name(caller_id)
    payload = %{"caller_id" => caller_id, "caller_name" => caller_name}

    devices
    |> APNS.pushkit_call(payload)
    |> Enum.any?(fn %Notification{response: response} -> response == :success end)
  end

  @spec fetch_name(Ecto.UUID.t()) :: String.t()
  defp fetch_name(user_id) do
    FeedProfile
    |> where(user_id: ^user_id)
    |> select([p], p.name)
    |> Repo.one!()
  end

  @spec get_call_role_and_peer(Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, :caller | :called, %FeedProfile{}} | {:error, :not_found | :ended}
  def get_call_role_and_peer(call_id, user_id) do
    Call
    |> where(id: ^call_id)
    |> where(caller_id: ^user_id)
    |> or_where(called_id: ^user_id)
    |> Repo.one()
    |> case do
      %Call{ended_at: %DateTime{}} -> {:error, :ended}
      %Call{caller_id: ^user_id, called_id: peer_id} -> {:ok, :caller, fetch_profile(peer_id)}
      %Call{called_id: ^user_id, caller_id: peer_id} -> {:ok, :called, fetch_profile(peer_id)}
      nil -> {:error, :not_found}
    end
  end

  @spec end_call(Ecto.UUID.t()) :: :ok
  def end_call(call_id) do
    ended_at = DateTime.truncate(DateTime.utc_now(), :second)

    {1, _} =
      Call
      |> where(id: ^call_id)
      |> Repo.update_all(set: [ended_at: ended_at])

    :ok
  end

  @spec fetch_profile(Ecto.UUID.t()) :: %FeedProfile{}
  defp fetch_profile(user_id) do
    FeedProfile
    |> where(user_id: ^user_id)
    |> Repo.one!()
  end

  @spec list_missed_calls_with_profile_and_session(Ecto.UUID.t(), Keyword.t()) :: [
          {%Call{}, %FeedProfile{}, %ActiveSession{} | nil}
        ]
  def list_missed_calls_with_profile_and_session(user_id, opts) do
    missed_calls_q(user_id, opts)
    |> join(:inner, [c], p in FeedProfile, on: c.caller_id == p.user_id)
    |> join(:left, [_c, p], s in ActiveSession, on: p.user_id == s.user_id)
    |> select([c, p, s], {c, p, s})
    |> Repo.all()
  end

  # TODO remove the ones hung up by user_id
  @spec missed_calls_q(Ecto.UUID.t(), Keyword.t()) :: Ecto.Query.t()
  defp missed_calls_q(user_id, opts) do
    Call
    |> where(called_id: ^user_id)
    |> where([c], is_nil(c.accepted_at))
    |> order_by(asc: :id)
    |> maybe_after_missed_calls(opts[:after])
  end

  defp maybe_after_missed_calls(query, nil), do: query
  defp maybe_after_missed_calls(query, after_id), do: where(query, [c], c.id > ^after_id)
end
