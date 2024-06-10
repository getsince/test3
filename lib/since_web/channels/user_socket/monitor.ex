# TODO possibly put user id in Phoenix.Tracker for 'global' key?
defmodule SinceWeb.UserSocket.Monitor do
  @moduledoc "Monitors user socket processes and updates user's last_active_at on `:DOWN`."
  use GenServer

  @task_supervisor __MODULE__.TaskSupervisor

  def start_link(_opts) do
    children = [
      {Task.Supervisor, name: @task_supervisor},
      %{id: :monitor, start: {__MODULE__, :start_link, []}}
    ]

    opts = [
      strategy: :rest_for_one,
      name: __MODULE__.Supervisor
    ]

    Supervisor.start_link(children, opts)
  end

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @spec monitor(pid, (-> any)) :: :ok
  def monitor(pid, on_down) when is_function(on_down, 0) do
    GenServer.cast(__MODULE__, {:monitor, pid, on_down})
  end

  @impl true
  def init(_opts) do
    # monitors: %{ref => on_down}
    {:ok, %{monitors: %{}}}
  end

  @impl true
  def handle_cast({:monitor, pid, on_down}, %{monitors: monitors} = state) do
    {:noreply, %{state | monitors: Map.put(monitors, Process.monitor(pid), on_down)}}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _object, _reason}, %{monitors: monitors} = state) do
    {on_down, monitors} = Map.pop!(monitors, ref)
    exec_on_down(state, on_down)
    {:noreply, %{state | monitors: monitors}}
  end

  defp exec_on_down(%{task_exec: f}, on_down) when is_function(f, 1) do
    f.(on_down)
  end

  defp exec_on_down(_state, on_down) do
    Task.Supervisor.start_child(@task_supervisor, on_down)
  end
end
