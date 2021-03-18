defmodule TWeb.TraceLive.Show do
  use TWeb, :live_view

  defmodule Message do
    defstruct [:direction, :title, :content]
  end

  @pubsub T.PubSub

  @impl true
  def mount(%{"user_id" => user_id}, _session, socket) do
    user = T.Accounts.get_user!(user_id)

    if connected?(socket) do
      :ok = Phoenix.PubSub.subscribe(@pubsub, "trace:#{user.id}")
      :ok = Phoenix.PubSub.subscribe(@pubsub, "matches:#{user.id}")
    end

    {:ok, assign(socket, user: user, user_options: all_user_options()),
     temporary_assigns: [messages: [], user_options: []]}
  end

  @impl true
  def handle_event("submit", %{"user" => user_id}, socket) do
    path = Routes.trace_show_path(socket, :show, user_id)
    {:noreply, push_redirect(socket, to: path)}
  end

  @impl true
  def handle_info({:trace, message}, socket) when is_tuple(message) do
    {:noreply, assign(socket, messages: [%Message{direction: :out, content: inspect(message)}])}
  end

  def handle_info({:trace, %{"event" => event, "payload" => payload}}, socket) do
    {:noreply, assign(socket, messages: [message_from_broadcast(event, :out, payload)])}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: event, payload: payload}, socket) do
    {:noreply, assign(socket, messages: [message_from_broadcast(event, :in, payload)])}
  end

  def handle_info(message, socket) do
    {:noreply, assign(socket, messages: [%Message{direction: :in, content: inspect(message)}])}
  end

  defp message_from_broadcast("peer-message", direction, %{"body" => body}) do
    case Jason.decode!(body) do
      %{"type" => "sdp", "content" => %{"type" => type, "sdp" => sdp}} ->
        %Message{direction: direction, title: type, content: sdp}

      %{"type" => "ice-candidate", "content" => content} ->
        %Message{
          direction: direction,
          title: "ice candidate",
          content: content |> Enum.map(fn {k, v} -> [k, ": ", v] end) |> Enum.intersperse("\n")
        }
    end
  end

  defp render_message(%Message{direction: direction, title: title, content: content}) do
    ~E"""
    <div class="font-semibold uppercase"><%= render_direction(direction) %> <%= title %></div>
    <pre class="whitespace-pre-wrap"><%= content %></pre>
    """
  end

  defp render_direction(:in) do
    "↓"
  end

  defp render_direction(:out) do
    "↑"
  end

  defp message_class(%Message{direction: :in}), do: "bg-blue-100"
  defp message_class(%Message{direction: :out}), do: "bg-green-100"
  defp message_class(_other), do: "bg-gray-100"

  defp all_user_options do
    import Ecto.Query

    T.Accounts.Profile
    |> Ecto.Query.select([p], {p.name, p.user_id})
    # |> where([p], p.user_id != ^user.id)
    |> order_by([p], desc: p.times_liked)
    |> T.Repo.all()
  end
end
