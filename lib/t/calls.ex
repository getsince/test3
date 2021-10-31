defmodule T.Calls do
  @moduledoc false
  import Ecto.Query

  require Logger

  alias T.{Repo, Twilio, Accounts}
  alias T.Calls.Call
  alias T.Feeds.{FeedProfile}
  alias T.Matches.Match
  alias T.PushNotifications.APNS
  alias T.Bot

  @spec ice_servers :: [map]
  def ice_servers do
    Twilio.ice_servers()
  end

  @spec call(Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, call_id :: Ecto.UUID.t()} | {:error, reason :: String.t()}
  def call(caller_id, called_id) do
    call_id = Ecto.Bigflake.UUID.generate()

    with {:allowed?, true} <- {:allowed?, call_allowed?(caller_id, called_id)},
         {:devices, [_ | _] = devices} <- {:devices, Accounts.list_pushkit_devices(called_id)},
         {:push, _any_push_sent? = true} <- {:push, push_call(caller_id, call_id, devices)} do
      %Call{id: ^call_id} =
        Repo.insert!(%Call{id: call_id, caller_id: caller_id, called_id: called_id})

      {:ok, call_id}
    else
      {:allowed?, false} -> {:error, "call not allowed"}
      {:devices, []} -> {:error, "no pushkit devices available"}
      {:push, false} -> {:error, "all pushes failed"}
    end
  end

  def call_allowed?(caller_id, called_id) do
    missed?(called_id, caller_id) or matched?(caller_id, called_id)
  end

  defp missed?(caller_id, called_id) do
    Call
    |> where(caller_id: ^caller_id)
    |> where(called_id: ^called_id)
    |> where([c], is_nil(c.accepted_at) and not is_nil(c.ended_at))
    |> Repo.exists?()
  end

  defp matched?(caller_id, called_id) do
    [user_id_1, user_id_2] = Enum.sort([caller_id, called_id])

    Match
    |> where(user_id_1: ^user_id_1)
    |> where(user_id_2: ^user_id_2)
    |> Repo.exists?()
  end

  @spec push_call(Ecto.UUID.t(), Ecto.UUID.t(), [%Accounts.PushKitDevice{}]) :: boolean
  def push_call(caller_id, call_id, devices) do
    caller_name = fetch_name(caller_id)
    payload = %{"caller_id" => caller_id, "call_id" => call_id, "caller_name" => caller_name}

    devices
    |> APNS.pushkit_call(payload)
    |> Enum.any?(fn response -> response == :ok end)
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

  @spec accept_call(Ecto.UUID.t(), DateTime.t()) :: :ok
  def accept_call(call_id, now \\ utc_now()) do
    {caller, called} =
      Call
      |> where(id: ^call_id)
      |> select([p], {p.caller_id, p.called_id})
      |> Repo.one!()

    m = "New call starts: #{fetch_name(caller)}(#{caller}) and #{fetch_name(called)}(#{called})"

    Logger.warn(m)
    Bot.async_post_message(m)

    match_id =
      Match
      |> where([m], m.user_id_1 == ^caller and m.user_id_2 == ^called)
      |> or_where([m], m.user_id_1 == ^called and m.user_id_2 == ^caller)
      |> order_by(desc: :inserted_at)
      |> limit(1)
      |> select([m], m.id)
      |> Repo.all()

    T.Matches.match_timeslot_new_event("#{match_id}", "call start")

    {1, _} =
      Call
      |> where(id: ^call_id)
      |> Repo.update_all(set: [accepted_at: now])

    :ok
  end

  @spec end_call(Ecto.UUID.t(), Ecto.UUID.t(), DateTime.t()) :: :ok
  def end_call(user_id, call_id, now \\ utc_now()) do
    m = "user #{fetch_name(user_id)}, id #{user_id} ended a call #{call_id}"

    Logger.warn(m)
    Bot.async_post_message(m)

    {1, _} =
      Call
      |> where(id: ^call_id)
      |> Repo.update_all(set: [ended_at: now, ended_by: user_id])

    :ok
  end

  @spec fetch_profile(Ecto.UUID.t()) :: %FeedProfile{}
  defp fetch_profile(user_id) do
    FeedProfile
    |> where(user_id: ^user_id)
    |> Repo.one!()
  end

  @spec list_missed_calls_with_profile(Ecto.UUID.t(), Keyword.t()) :: [
          {%Call{}, %FeedProfile{} | nil}
        ]
  def list_missed_calls_with_profile(user_id, opts) do
    missed_calls_q(user_id, opts)
    |> join(:inner, [c], p in FeedProfile, on: c.caller_id == p.user_id)
    |> select([c, p], {c, p})
    |> Repo.all()
  end

  @spec missed_calls_q(Ecto.UUID.t(), Keyword.t()) :: Ecto.Query.t()
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
end
