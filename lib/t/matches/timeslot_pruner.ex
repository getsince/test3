defmodule T.Matches.TimeslotPruner do
  @moduledoc """
  Prunes expired timeslot offers (older than 30 min) and selected timeslots (older than 60 minutes)
  """
  use GenServer
  alias T.Matches

  @doc """

      default_opts = [check_interval: :timer.minutes(1)]

  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    check_interval = opts[:check_interval] || :timer.minutes(1)
    {:ok, schedule_prune(%{check_interval: check_interval})}
  end

  def prune do
    Matches.prune_stale_timeslots()
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
