# TODO possibly put user id in Phoenix.Tracker for 'global' key?
defmodule TWeb.UserSocket.Monitor do
  @moduledoc "Monitors user socket processes and updates user's last_active_at on `:DOWN`."
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec monitor(pid | module, pid, binary) :: :ok
  def monitor(server \\ __MODULE__, pid, user_id) do
    GenServer.cast(server, {:monitor, pid, user_id})
  end

  @impl true
  def init(_opts) do
    {:ok, _monitors = %{}}
  end

  @impl true
  def handle_cast({:monitor, pid, user_id}, monitors) do
    ref = Process.monitor(pid)
    {:noreply, Map.put(monitors, ref, user_id)}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _object, _reason}, monitors) do
    {user_id, monitors} = Map.pop!(monitors, ref)
    on_down(user_id)
    {:noreply, monitors}
  end

  # TODO update last active on other actions as well, 'like', 'match', etc.
  defp on_down(user_id) do
    T.Accounts.update_last_active(user_id)
    # TODO wait in tests for monitor somehow
  rescue
    _ -> :ok
  catch
    :exit, _ -> :ok
  end
end
