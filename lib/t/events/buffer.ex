defmodule T.Events.Buffer do
  @moduledoc false
  use GenServer

  alias T.Events.{Repo, Event}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  @impl true
  def init(_opts) do
    Process.send_after(self(), :flush_buffer, :timer.seconds(10))
    {:ok, _buffer = []}
  end

  @impl true
  def handle_cast({:add, event}, buffer) do
    # TODO flush if events > 1000, don't use length(buffer) but keep a separate counter
    {:noreply, [event | buffer]}
  end

  @impl true
  def handle_info(:flush_buffer, buffer) do
    flush_buffer(buffer)
    Process.send_after(self(), :flush_buffer, :timer.seconds(10))
    {:noreply, _buffer = []}
  end

  defp flush_buffer(_empty = []), do: {0, nil}

  defp flush_buffer(buffer) do
    Repo.insert_all(Event, :lists.reverse(buffer))
  end
end
