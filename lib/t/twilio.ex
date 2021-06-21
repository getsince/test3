defmodule T.Twilio do
  @moduledoc "Basic Twilio client with cached ice servers"
  use GenServer

  defmodule State do
    defstruct ttl_timers: %{}
  end

  @table __MODULE__

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def ice_servers do
    cached(:ice_servers, fn -> fetch_ice_servers() end)
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
    state = clean_timers_for_key(state, key)
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

  defp clean_timers_for_key(state, key) do
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
    timer = Process.send_after(self(), {:expire, key}, ttl)
    %State{state | ttl_timers: Map.put(timers, key, timer)}
  end

  def creds do
    config = Application.get_env(:t, __MODULE__)
    Map.new(config)
  end

  # TODO lower ttl (24h right now)
  # TODO don't leak secrets to logs
  if Mix.env() == :test do
    def fetch_ice_servers do
      # TODO
      %{}
    end
  else
    def fetch_ice_servers do
      %{account_sid: account_sid, key_sid: key_sid, auth_token: auth_token} = creds()

      url = "https://api.twilio.com/2010-04-01/Accounts/#{account_sid}/Tokens.json"
      headers = [{"Authorization", basic_auth(key_sid, auth_token)}]

      req = Finch.build(:post, url, headers)
      {:ok, %Finch.Response{status: 201, body: body}} = Finch.request(req, T.Finch)

      %{"ice_servers" => ice_servers} = Jason.decode!(body)
      ice_servers
    end

    defp basic_auth(username, password) do
      "Basic " <> Base.encode64(username <> ":" <> password)
    end
  end
end
