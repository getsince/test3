defmodule Periodic do
  @moduledoc "Runs a given task repeatedly with specified period in-between the runs"
  use GenServer

  @type state :: {period :: pos_integer(), task :: (() -> any) | {module, atom, [term]}}

  @spec start_link(state) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(state) do
    GenServer.start_link(__MODULE__, state)
  end

  @impl true
  @spec init(state) :: {:ok, state}
  def init({_period, _task} = state) do
    {:ok, schedule_task(state)}
  end

  @impl true
  @spec handle_info(:run, state) :: {:noreply, state}
  def handle_info(:run, {_period, task} = state) do
    run(task)
    {:noreply, schedule_task(state)}
  end

  @spec schedule_task(state) :: state
  defp schedule_task({period, _task} = state) do
    Process.send_after(self(), :run, period)
    state
  end

  defp run({m, f, a}), do: apply(m, f, a)
  defp run(f) when is_function(f, 0), do: f.()
end
