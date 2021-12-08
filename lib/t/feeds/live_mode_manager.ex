defmodule T.Feeds.LiveModeManager do
  @moduledoc """
  Schedules live mode pushes: start & end; cleans live_sessions and live_invites after that
  """

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    live_mode = opts[:live_mode] || false
    check_interval = opts[:check_interval] || :timer.seconds(1)
    :timer.send_interval(check_interval, :check_mode_change)
    {:ok, %{live_mode: live_mode}}
  end

  @impl true
  def handle_info(:check_mode_change, %{live_mode: previous_mode} = _state) do
    current_mode = T.Feeds.is_now_live_mode()

    case {previous_mode, current_mode} do
      {false, true} ->
        T.Feeds.notify_live_mode_start()

      {true, false} ->
        T.Feeds.notify_live_mode_end()
        T.Feeds.clear_live_tables()

      _ ->
        nil
    end

    {:noreply, %{live_mode: current_mode}}
  end
end
