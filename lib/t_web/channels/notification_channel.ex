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

  # TODO don't send push notifications if the user is online in this channel?
  # TODO test if joined, then in feed returned as online
  @impl true
  def handle_info(:after_join, socket) do
    # TODO need it?
    {:ok, _} = Presence.track(self(), "global", socket.assigns.current_user.id, %{})

    # TODO
    {:ok, _} =
      Presence.track(
        self(),
        "online:#{socket.assigns.current_user.id}",
        socket.assigns.current_user.id,
        %{}
      )

    {:noreply, socket}
  end
end
