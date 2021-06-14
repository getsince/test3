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
    @enforce_keys [:key, :label, :e_tag, :meta]
    defstruct [:key, :label, :e_tag, :meta]

    def new(ets_row) do
      {label, key, e_tag, last_modified, size} = ets_row

      %__MODULE__{
        label: label,
        key: key,
        e_tag: e_tag,
        meta: %{last_modified: last_modified, size: size}
      }
    end
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def lookup_key_and_e_tag(label) do
    case :ets.lookup(@table, label) do
      [{^label, key, e_tag, _last_modified, _size}] -> {key, e_tag}
      [] -> nil
    end
  end

  def lookup_object(label) do
    case :ets.lookup(@table, label) do
      [{^label, _key, _e_tag, _last_modified, _size} = row] -> Object.new(row)
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
    {:ok, nil, {:continue, :refresh}}
  end

  @impl true
  def handle_continue(:refresh, state) do
    _ = refresh()
    {:noreply, state}
  end

  @impl true
  def handle_info(:refresh, state) do
    _ = refresh()
    {:noreply, state}
  end

  def handle_info({__MODULE__, :updated}, state) do
    # just in case aws didn't propagate the change yet, schedule another refresh in 10 sec
    Process.send_after(self(), :refresh, :timer.seconds(10))
    _ = refresh()
    {:noreply, state}
  end

  defp refresh do
    true = :ets.delete_all_objects(@table)

    Enum.map(Media.list_static_files(), fn object ->
      %{e_tag: e_tag, key: key, last_modified: last_modified, size: size} = object
      e_tag = String.replace(e_tag, "\"", "")
      ets_row = {trim_extension(key), key, e_tag, last_modified, size}
      true = :ets.insert(@table, ets_row)
      Object.new(ets_row)
    end)
  end

  defp trim_extension(s3_key) do
    extname = Path.extname(s3_key)
    String.replace_trailing(s3_key, extname, "")
  end
end
