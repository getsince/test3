defmodule TWeb.MatchChannel do
  use TWeb, :channel
  alias TWeb.MatchView
  alias T.Matches

  @impl true
  def join("match:" <> user_ids, _params, socket) do
    user_ids = ChannelHelpers.extract_user_ids(user_ids)
    ChannelHelpers.verify_user_id(socket, user_ids)
    other_user_id = ChannelHelpers.other_user_id(socket, user_ids)
    other_user_online? = ChannelHelpers.user_online?(other_user_id)
    {:ok, %{online?: other_user_online?}, socket}
  end

  @impl true
  def handle_in("message", %{"message" => params}, socket) do
    {:ok, message} = Matches.save_message(socket.assigns.current_user, params)
    broadcast_from!(socket, "message", render(MatchView, "message.json", message: message))
    {:reply, :ok, socket}
  end

  # TODO message read
  # def handle_in("")

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
