defmodule T.Twilio do
  @moduledoc "Basic Twilio client with cached ice servers"
  use GenServer

  @adapter Application.compile_env!(:t, [__MODULE__, :adapter])

  defmodule State do
    defstruct ttl_timers: %{}
  end

  @table __MODULE__

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def ice_servers do
    cached(:ice_servers, fn -> @adapter.fetch_ice_servers() end)
  end

  def creds do
    config = Application.get_env(:t, __MODULE__)
    Map.new(config)
  end

  defp cached(key, fallback) do
    case :ets.lookup(@table, key) do
      [] ->
        # race condition possible, with multiple clients sending reqs here
        val = fallback.()
        GenServer.cast(__MODULE__, {:store, key, val, ttl: :timer.hours(12)})
        val

      [{^key, val}] ->
        val
    end
  end

  @impl true
  def init(_opts) do
    @table = :ets.new(@table, [:named_table, :protected])
    {:ok, %State{}}
  end

  @impl true
  def handle_cast({:store, key, val, opts}, state) do
    state = clean_timer_for_key(state, key)
    true = :ets.insert(@table, {key, val})
    state = schedule_cleanup_for_key(state, key, opts[:ttl])
    {:noreply, state}
  end

  @impl true
  def handle_info({:expire, key}, state) do
    {_timer, timers} = pop_timer(state, key)
    true = :ets.delete(@table, key)
    {:noreply, %State{state | ttl_timers: timers}}
  end

  defp clean_timer_for_key(state, key) do
    {timer, timers} = pop_timer(state, key)

    if timer do
      {:ok, :cancel} = :timer.cancel(timer)
    end

    %State{state | ttl_timers: timers}
  end

  defp pop_timer(state, key) do
    %State{ttl_timers: timers} = state
    Map.pop(timers, key)
  end

  defp schedule_cleanup_for_key(state, _key, nil), do: state

  defp schedule_cleanup_for_key(state, key, ttl) do
    %State{ttl_timers: timers} = state
    {:ok, timer} = :timer.send_after(ttl, {:expire, key})
    %State{state | ttl_timers: Map.put(timers, key, timer)}
  end
end
