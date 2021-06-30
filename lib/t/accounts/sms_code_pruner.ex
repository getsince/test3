defmodule T.Accounts.SMSCodePruner do
  @moduledoc """
  Periodically deletes sms_codes rows from DB that have inserted_at < now() - interval '<ttl>' (with default ttl = 300 seconds)
  """

  use GenServer

  @doc """

      default_opts = [ttl_seconds: 300, check_interval: :timer.minutes(5)]

  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    ttl_seconds = opts[:ttl_seconds] || 300
    check_interval = opts[:check_interval] || :timer.minutes(5)
    :timer.send_interval(check_interval, :prune)
    {:ok, %{ttl_seconds: ttl_seconds}}
  end

  @doc false
  def prune(ttl_seconds) do
    T.Accounts.PasswordlessAuth.prune(ttl_seconds)
  end

  @impl true
  def handle_info(:prune, %{ttl_seconds: ttl_seconds} = state) do
    prune(ttl_seconds)
    {:noreply, state}
  end
end
