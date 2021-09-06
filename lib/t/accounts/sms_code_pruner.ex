defmodule T.Accounts.SMSCodePruner do
  @moduledoc """
  Periodically deletes sms_codes rows from DB that have inserted_at < now() - interval '<ttl>' (with default ttl = 300 seconds)
  """

  use GenServer
  alias T.Accounts.PasswordlessAuth

  @doc """

      default_opts = [ttl_seconds: 300, check_interval: :timer.minutes(5)]

  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    state = %{
      ttl_seconds: opts[:ttl_seconds] || 300,
      check_interval: opts[:check_interval] || :timer.minutes(5)
    }

    schedule_next_prune(state)
    {:ok, state}
  end

  defp schedule_next_prune(%{check_interval: check_interval}) do
    Process.send_after(self(), :prune, check_interval)
  end

  @impl true
  def handle_info(:prune, %{ttl_seconds: ttl_seconds} = state) do
    PasswordlessAuth.prune(ttl_seconds)
    schedule_next_prune(state)
    {:noreply, state}
  end
end
