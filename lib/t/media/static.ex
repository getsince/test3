defmodule T.Media.Static do
  @moduledoc "In-memory write-through cache of static (stickers) object keys on AWS S3."
  use GenServer
  alias T.{Media, Media.Client}

  @table __MODULE__
  @task_sup T.TaskSupervisor
  @pubsub T.PubSub
  @topic to_string(__MODULE__)

  defp notify_subscribers(event) do
    Phoenix.PubSub.broadcast!(@pubsub, @topic, {__MODULE__, event})
  end

  defmodule Object do
    @moduledoc false
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

    def to_row(%__MODULE__{
          key: key,
          e_tag: e_tag,
          meta: %{last_modified: last_modified, size: size}
        }) do
      {key, e_tag, last_modified, size}
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

  @spec list_cached :: [%Object{}]
  def list_cached do
    ets_rows = :ets.tab2list(@table)
    Enum.map(ets_rows, fn row -> Object.new(row) end)
  end

  @impl true
  def init(_opts) do
    @table = :ets.new(@table, [:named_table])
    Phoenix.PubSub.subscribe(@pubsub, @topic)
    {:ok, {:continue, :refresh}}
  end

  @impl true
  def handle_continue(:refresh, _refresh_task_ref = nil) do
    Media.static_bucket()
    |> Client.list_objects()
    |> Enum.map(fn object ->
      %{e_tag: e_tag, key: key, last_modified: last_modified, size: size} = object
      e_tag = String.replace(e_tag, "\"", "")
      _ets_row = {key, e_tag, last_modified, size}
    end)

    {:noreply, _refresh_task_ref = nil}
  end

  @impl true
  def handle_call({command, _object} = message, _from, ref) when command in [:add, :remove] do
    notify_subscribers(message)
    {:reply, :ok, ref}
  end

  @impl true
  def handle_cast(:refresh, nil) do
    {:noreply, async_refresh()}
  end

  def handle_cast(:refresh, ref) when is_reference(ref) do
    {:noreply, ref}
  end

  @impl true
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

  def handle_info({__MODULE__, {:add, object}}, ref) do
    :ets.insert(@table, Object.to_row(object))
    {:noreply, ref}
  end

  def handle_info({__MODULE__, {:remove, key}}, ref) do
    :ets.delete(@table, key)
    {:noreply, ref}
  end

  defp async_refresh do
    task = Task.Supervisor.async_nolink(@task_sup, fn -> refresh() end)
    task.ref
  end

  defp refresh do
    Enum.map(Media.list_static_files(), fn object ->
      %{e_tag: e_tag, key: key, last_modified: last_modified, size: size} = object
      e_tag = String.replace(e_tag, "\"", "")
      _ets_row = {key, e_tag, last_modified, size}
    end)
  end
end
