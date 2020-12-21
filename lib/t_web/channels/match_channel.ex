defmodule TWeb.MatchChannel do
  use TWeb, :channel

  @impl true
  def join("match:" <> user_ids, _params, socket) do
    user_ids = ChannelHelpers.extract_user_ids(user_ids)
    ChannelHelpers.verify_user_id(socket, user_ids)

    {:ok, socket}
  end

  @impl true
  # def handle_in("message", %{"message" => params}, socket) do
  #   :ok = T.Matches.save_message(socket.assigns.user, params)
  #   {:reply, :ok, socket}
  # end

  def handle_in("leave", _params, socket) do
    {:reply, :ok, socket}
  end

  def handle_in("report", %{"reason" => _reason}, socket) do
    {:reply, :ok, socket}
  end

  def handle_in("media:signed_url", _params, socket) do
    {:reply, :ok, socket}
  end

  def handle_in("media:uploaded", _params, socket) do
    {:reply, :ok, socket}
  end
end
