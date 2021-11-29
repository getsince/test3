defmodule T.Matches.MatchCalls do
  use GenServer

  @doc """
      default_opts = [ttl_days: 1, check_interval: :timer.minutes(1)]
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    check_interval = opts[:check_interval] || :timer.seconds(5)
    :timer.send_interval(check_interval, :prune)
    {:ok, %{check_interval: check_interval}}
  end

  def prune() do
    T.Matches.check_matches_calls()
  end

  @impl true
  def handle_info(:prune, state) do
    prune()
    {:noreply, state}
  end
end
