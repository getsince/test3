# TODO possibly put user id in Phoenix.Tracker for 'global' key?
defmodule TWeb.UserSocket.Monitor do
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

  @spec monitor(pid, binary) :: :ok
  def monitor(pid, user_id) do
    GenServer.cast(__MODULE__, {:monitor, pid, user_id})
  end

  def on_down_tasks do
    Task.Supervisor.children(@task_supervisor)
  end

  @impl true
  def init(_opts) do
    # %{ref => user_id}
    {:ok, _monitors = %{}}
  end

  @impl true
  def handle_cast({:monitor, pid, user_id}, monitors) do
    {:noreply, Map.put(monitors, Process.monitor(pid), user_id)}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _object, _reason}, monitors) do
    {user_id, monitors} = Map.pop!(monitors, ref)
    on_down(user_id)
    {:noreply, monitors}
  end

  # TODO update last active on other actions as well, 'like', 'match', etc.
  defp on_down(user_id) do
    Task.Supervisor.start_child(@task_supervisor, fn ->
      T.Accounts.update_last_active(user_id)
    end)
  end
end
