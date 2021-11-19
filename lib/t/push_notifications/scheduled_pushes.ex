defmodule T.PushNotifications.ScheduledPushes do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    check_interval = opts[:check_interval] || :timer.minutes(1)
    :timer.send_interval(check_interval, :send_pushes)
    {:ok, %{check_interval: check_interval}}
  end

  def send_pushes() do
    T.Accounts.push_users_to_complete_onboarding()
  end

  @impl true
  def handle_info(:send_pushes, state) do
    send_pushes()
    {:noreply, state}
  end
end
