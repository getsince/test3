defmodule T.Calls do
  @moduledoc "Handles call signalling"

  import Ecto.Query

  alias T.{Repo, Twilio, Accounts}
  alias T.Calls.Call
  alias T.Feeds.FeedProfile
  alias T.PushNotifications.APNS

  @spec ice_servers :: [map]
  def ice_servers do
    Twilio.ice_servers()
  end

  @spec call(Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, call_id :: Ecto.UUID.t()} | {:error, reason :: String.t()}
  def call(caller_id, called_id) do
    with {:devices, [_ | _] = devices} <- {:devices, Accounts.list_pushkit_devices(called_id)},
         {:push, _any_push_sent? = true} <- {:push, push_call(caller_id, devices)} do
      %Call{id: call_id} = Repo.insert!(%Call{caller_id: caller_id, called_id: called_id})
      {:ok, call_id}
    else
      {:devices, []} -> {:error, "no pushkit devices available"}
      {:push, false} -> {:error, "all pushes failed"}
    end
  end

  @spec push_call(Ecto.UUID.t(), [base16 :: String.t()]) :: boolean
  defp push_call(caller_id, devices) do
    alias Pigeon.APNS.Notification

    caller_name = fetch_name(caller_id)
    payload = %{"caller_id" => caller_id, "caller_name" => caller_name}

    devices
    |> Enum.map(fn device -> APNS.pushkit_call(device, payload) end)
    |> Enum.any?(fn chunk ->
      Enum.any?(chunk, fn %Notification{response: response} ->
        response == :success
      end)
    end)
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
      %Call{caller_id: ^user_id, called_id: peer_id} -> {:ok, :caller, fetch_profile(peer_id)}
      %Call{called_id: ^user_id, caller_id: peer_id} -> {:ok, :called, fetch_profile(peer_id)}
      %Call{ended_at: %DateTime{}} -> {:error, :ended}
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
end
