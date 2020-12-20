defmodule TWeb.NotificationChannel do
  use TWeb, :channel

  @impl true
  def join("notification:" <> user_id, _params, socket) do
    ChannelHelpers.verify_user_id(socket, user_id)
    {:ok, socket}
  end
end
