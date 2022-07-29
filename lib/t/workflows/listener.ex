defmodule T.Workflows.Listener do
  @moduledoc false
  use GenServer
  alias T.Workflows

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, _state = nil}
  end

  @impl true
  def handle_info({:register, Workflows.Registry, workflow_id, pid, _meta}, state) do
    Workflows.broadcast(:up, {workflow_id, pid})
    Process.monitor(pid)
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    Workflows.broadcast(:down, pid)
    {:noreply, state}
  end
end
