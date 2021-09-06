defmodule T.Feeds.ActiveSessionPruner do
  @moduledoc """
  Periodically deletes active_sessions rows from DB that have expires_at < now()
  """

  use GenServer
  alias T.Feeds

  @doc """

      default_opts = [check_interval: :timer.minutes(1)]

  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    check_interval = opts[:check_interval] || :timer.minutes(1)
    schedule_next_prune(check_interval)
    {:ok, check_interval}
  end

  @impl true
  def handle_info(:prune, check_interval) do
    Feeds.delete_expired_sessions()
    schedule_next_prune(check_interval)
    {:noreply, check_interval}
  end

  defp schedule_next_prune(interval) do
    Process.send_after(self(), :prune, interval)
  end
end
