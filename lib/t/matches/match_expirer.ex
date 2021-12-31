defmodule T.Matches.MatchExpirer do
  use GenServer
  alias T.Matches

  @doc """

      default_opts = [check_interval: :timer.minutes(1)]

  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    check_interval = opts[:check_interval] || :timer.minutes(1)
    {:ok, schedule_prune(%{check_interval: check_interval})}
  end

  def prune do
    Matches.expiration_notify_soon_to_expire()
    Matches.expiration_prune()
  end

  @impl true
  def handle_info(:prune, state) do
    prune()
    {:noreply, schedule_prune(state)}
  end

  defp schedule_prune(%{check_interval: interval} = state) do
    Process.send_after(self(), :prune, interval)
    state
  end
end
