defmodule T.Feeds.ActiveSessionPruner do
  @moduledoc """
  Periodically deletes active_sessions rows from DB that have expires_at < now()
  """

  use GenServer

  @doc """

      default_opts = [check_interval: :timer.minutes(1)]

  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    check_interval = opts[:check_interval] || :timer.minutes(1)
    :timer.send_interval(check_interval, :prune)
    {:ok, nil}
  end

  @doc false
  def prune() do
    T.Feeds2.delete_expired_sessions()
  end

  @impl true
  def handle_info(:prune, state) do
    prune()
    {:noreply, state}
  end
end
