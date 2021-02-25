defmodule TWeb.AudioLive.Index do
  use TWeb, :live_view
  alias TWeb.Presence

  @impl true
  def mount(%{"user_id" => user_id, "mate_id" => mate_id}, _session, socket) do
    me = T.Accounts.get_user!(user_id) |> T.Repo.preload(:profile)
    mate = T.Accounts.get_user!(mate_id) |> T.Repo.preload(:profile)
    match = ensure_match(me, mate)
    topic = topic(me.id)

    socket = assign(socket, presences: [])

    socket =
      if connected?(socket) do
        # track self for mate
        {:ok, _} = Presence.track(self(), "matches:#{mate.id}", me.id, %{})
        TWeb.Endpoint.subscribe(topic)
        assign(socket, presences: presences(topic))
        # if both are online, push event to client to start connecting
      else
        socket
      end

    {:ok, assign(socket, me: me, mate: mate, match: match, topic: topic)}
  end

  defp ensure_match(me, mate) do
    import Ecto.Query
    [user_id_1, user_id_2] = Enum.sort([me.id, mate.id])

    T.Repo.insert!(%T.Matches.Match{user_id_1: user_id_1, user_id_2: user_id_2, alive?: true},
      on_conflict: :nothing
    )

    T.Matches.Match
    |> where(user_id_1: ^user_id_1)
    |> where(user_id_2: ^user_id_2)
    |> where(alive?: true)
    |> T.Repo.one!()
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    topic = socket.assigns.topic
    {:noreply, assign(socket, presences: presences(topic))}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{event: "peer-message" = event, payload: payload},
        socket
      ) do
    {:noreply, push_event(socket, event, payload)}
  end

  defp presences(topic) do
    topic |> Presence.list() |> Map.keys()
  end

  defp topic(user_id) do
    "matches:#{user_id}"
  end

  @impl true
  def handle_event("ice-servers", _params, socket) do
    {:reply, %{ice_servers: T.Twilio.ice_servers()}, socket}
  end

  def handle_event("peer-message" = event, %{"body" => _body} = payload, socket) do
    mate = socket.assigns.mate
    topic = "matches:#{mate.id}"
    TWeb.Endpoint.broadcast!(topic, event, payload)
    {:noreply, socket}
  end
end
