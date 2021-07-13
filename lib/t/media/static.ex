defmodule T.Media.Static do
  @moduledoc "In-memory cache of static files (only their keys) on AWS with periodic refresh."
  use GenServer
  alias T.Media

  @table __MODULE__
  @pubsub T.PubSub
  @topic to_string(__MODULE__)

  defp notify_subscribers(event) do
    Phoenix.PubSub.broadcast!(@pubsub, @topic, {__MODULE__, event})
  end

  def notify_s3_updated do
    notify_subscribers(:updated)
  end

  defmodule Object do
    @enforce_keys [:key, :e_tag, :meta]
    defstruct [:key, :e_tag, :meta]

    def new(ets_row) do
      {key, e_tag, last_modified, size} = ets_row

      %__MODULE__{
        key: key,
        e_tag: e_tag,
        meta: %{last_modified: last_modified, size: size}
      }
    end
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def lookup_etag(key) do
    case :ets.lookup(@table, key) do
      [{^key, e_tag, _last_modified, _size}] -> e_tag
      [] -> nil
    end
  end

  def lookup_object(key) do
    case :ets.lookup(@table, key) do
      [{^key, _e_tag, _last_modified, _size} = row] -> Object.new(row)
      [] -> nil
    end
  end

  def list do
    ets_rows = :ets.tab2list(@table)
    Enum.map(ets_rows, fn row -> Object.new(row) end)
  end

  @impl true
  def init(_opts) do
    @table = :ets.new(@table, [:named_table])
    Phoenix.PubSub.subscribe(@pubsub, @topic)
    :timer.send_interval(:timer.minutes(1), :refresh)
    {:ok, _refresh_task_ref = nil, {:continue, :refresh}}
  end

  @impl true
  def handle_continue(:refresh, _refresh_task_ref) do
    {:noreply, async_refresh()}
  end

  @impl true
  def handle_info(:refresh, _refresh_task_ref) do
    {:noreply, async_refresh()}
  end

  def handle_info({__MODULE__, :updated}, _refresh_task_ref) do
    # just in case aws didn't propagate the change yet, schedule another refresh in 10 sec
    Process.send_after(self(), :refresh, :timer.seconds(10))
    {:noreply, async_refresh()}
  end

  def handle_info({ref, [{_key, _e_tag, _last_modified, _size} | _rest] = ets_rows}, ref) do
    Process.demonitor(ref, [:flush])
    true = :ets.delete_all_objects(@table)
    Enum.map(ets_rows, fn ets_row -> true = :ets.insert(@table, ets_row) end)
    {:noreply, nil}
  end

  def handle_info({:DOWN, ref, :process, _pid, _error}, ref) do
    Process.send_after(self(), :refresh, :timer.seconds(3))
    {:noreply, nil}
  end

  defp async_refresh do
    task =
      Task.Supervisor.async_nolink(T.TaskSupervisor, fn ->
        Enum.map(Media.list_static_files(), fn object ->
          %{e_tag: e_tag, key: key, last_modified: last_modified, size: size} = object
          e_tag = String.replace(e_tag, "\"", "")
          _ets_row = {key, e_tag, last_modified, size}
        end)
      end)

    task.ref
  end
end
