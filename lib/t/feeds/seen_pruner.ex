defmodule T.Feeds.SeenPruner do
  @moduledoc """
  Periodically deletes seen_profiles rows from DB that
  have inserted_at < now() - interval '<ttl>' (with default ttl = 1 days)
  """

  use GenServer

  @doc """
      default_opts = [ttl_days: 1, check_interval: :timer.hours(1)]
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    ttl_days = opts[:ttl_days] || 1
    check_interval = opts[:check_interval] || :timer.hours(1)
    :timer.send_interval(check_interval, :prune)
    {:ok, %{ttl_days: ttl_days}}
  end

  @doc false
  def prune(ttl_days) do
    T.Feeds.prune_seen_profiles(ttl_days)
  end

  @impl true
  def handle_info(:prune, %{ttl_days: ttl_days} = state) do
    prune(ttl_days)
    {:noreply, state}
  end
end
