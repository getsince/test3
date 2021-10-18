defmodule TWeb.CallChannel do
  @moduledoc "Calls for alternative app."
  use TWeb, :channel

  alias TWeb.Presence
  alias T.Calls
  alias T.CallTopics

  @impl true
  def join("call:" <> call_id, params, socket) do
    %{current_user: current_user, screen_width: screen_width} = socket.assigns
    socket = assign(socket, call_id: call_id)

    locale = params["locale"]

    topics =
      case locale do
        nil -> CallTopics.locale_topics("en")
        _ -> CallTopics.locale_topics(locale)
      end

    case Calls.get_call_role_and_peer(call_id, current_user.id) do
      {:ok, :caller = role, _peer} ->
        send(self(), :after_join)
        reply = %{ice_servers: Calls.ice_servers(), call_topics: topics}
        {:ok, reply, assign(socket, role: role)}

      {:ok, :called = role, peer} ->
        send(self(), :after_join)

        reply = %{
          caller: render_peer(peer, screen_width),
          ice_servers: Calls.ice_servers(),
          call_topics: topics
        }

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
    {:reply, :ok, socket}
  end

  def handle_in("pick-up", _params, socket) do
    %{call_id: call_id, role: role} = socket.assigns

    case role do
      :called ->
        :ok = Calls.accept_call(call_id)
        broadcast_from!(socket, "pick-up", %{})
        {:reply, :ok, socket}

      :caller ->
        {:reply, {:error, %{"reason" => "not_called"}}, socket}
    end
  end

  def handle_in("hang-up", _params, socket) do
    # also when last user disconnects, call ends as well?
    broadcast_from!(socket, "hang-up", %{})
    %{current_user: user, call_id: call_id} = socket.assigns
    :ok = Calls.end_call(user.id, call_id)
    {:reply, :ok, socket}
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
