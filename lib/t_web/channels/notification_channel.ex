defmodule TWeb.NotificationChannel do
  use TWeb, :channel
  alias TWeb.Presence

  @impl true
  def join("notification:" <> user_id, _params, socket) do
    ChannelHelpers.verify_user_id(socket, user_id)
    send(self(), :after_join)
    # TODO subscribe for user events
    {:ok, socket}
  end

  # TODO don't send push notifications if the user is online in this channel
  @impl true
  def handle_info(:after_join, socket) do
    {:ok, _} =
      Presence.track(socket.channel_pid, "global", socket.assigns.current_user.id, %{
        online_at: inspect(System.system_time(:second))
      })

    {:noreply, socket}
  end
end
