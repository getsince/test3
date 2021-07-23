defmodule TWeb.CallChannel do
  use TWeb, :channel

  alias TWeb.Presence
  alias T.Calls

  @impl true
  def join("call:" <> call_id, _params, socket) do
    %{current_user: current_user, screen_width: screen_width} = socket.assigns
    socket = assign(socket, call_id: call_id)

    case Calls.get_call_role_and_peer(call_id, current_user.id) do
      {:ok, :caller = role, _peer} ->
        send(self(), :after_join)
        reply = %{ice_servers: Calls.ice_servers()}
        {:ok, reply, assign(socket, role: role)}

      {:ok, :called = role, peer} ->
        send(self(), :after_join)
        reply = %{caller: render_peer(peer, screen_width), ice_servers: Calls.ice_servers()}
        {:ok, reply, assign(socket, role: role)}

      {:error, :not_found} ->
        {:error, %{"reason" => "not_found"}}

      {:error, :ended} ->
        {:error, %{"reason" => "ended"}}
    end
  end

  @impl true
  def handle_in("peer-message", %{"body" => body}, socket) do
    me = socket.assigns.current_user.id
    # TODO check that the peer is online?
    broadcast_from!(socket, "peer-message", %{"from" => me, "body" => body})
    {:noreply, socket}
  end

  def handle_in("pick-up", _params, socket) do
    :called = socket.assigns.role
    broadcast_from!(socket, "pick-up", %{})
    {:noreply, socket}
  end

  def handle_in("hang-up", _params, socket) do
    # also when last user disconnects, call ends as well?
    broadcast_from!(socket, "hang-up", %{})
    :ok = Calls.end_call(socket.assigns.call_id)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:after_join, socket) do
    # TODO possibly remove self from feed channel?
    {:ok, _} = Presence.track(socket, socket.assigns.current_user.id, %{})
    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  defp render_peer(profile, screen_width) do
    render(TWeb.FeedView, "feed_profile.json", profile: profile, screen_width: screen_width)
  end
end
