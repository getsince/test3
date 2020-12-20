defmodule TWeb.ProfileChannel do
  use TWeb, :channel

  @impl true
  def join("profile:" <> user_id, _params, socket) do
    ChannelHelpers.verify_user_id(socket, user_id)
    {:ok, socket}
  end

  # @impl true
  # def handle_in("save", %{"profile" => params}, socket) do
  #   :ok = T.Profiles.save_profile(socket.assigns.user, params)
  #   {:reply, :ok, socket}
  # end
end
