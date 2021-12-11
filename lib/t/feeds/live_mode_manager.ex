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
    :timer.send_interval(check_interval, :live_mode_actions)
    {:ok, %{live_mode: live_mode}}
  end

  defp check_mode_change(previous_mode) do
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

    current_mode
  end

  # TODO refactor
  defp check_live_mode_today_or_soon() do
    day_of_week = Date.utc_today() |> Date.day_of_week()
    %{hour: hour, minute: minute, second: second} = Time.utc_now()

    case day_of_week do
      4 ->
        if hour == 10 && minute == 0 && second == 0, do: T.Feeds.notify_live_mode_will_be_today()
        if hour == 15 && minute == 45 && second == 0, do: T.Feeds.notify_live_mode_soon()

      6 ->
        if hour == 10 && minute == 0 && second == 0, do: T.Feeds.notify_live_mode_will_be_today()
        if hour == 16 && minute == 45 && second == 0, do: T.Feeds.notify_live_mode_soon()
    end
  end

  @impl true
  def handle_info(:live_mode_actions, %{live_mode: previous_mode} = _state) do
    current_mode = check_mode_change(previous_mode)

    check_live_mode_today_or_soon()

    {:noreply, %{live_mode: current_mode}}
  end
end
