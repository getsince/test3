defmodule TWeb.SupportLive.Index do
  use TWeb, :live_view
  alias T.{Support, Media}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Support.subscribe_to_all_messages()
    end

    last_messages = Support.list_last_messages()
    side_panel = build_side_panel(last_messages)

    {:ok, assign(socket, side_panel: side_panel, user_id: nil, messages: []),
     temporary_assigns: [messages: []]}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(params, socket.assigns.live_action, socket)}
  end

  defp apply_action(_params, :index, socket) do
    if last_message = List.last(socket.assigns.side_panel) do
      %{user_id: user_id} = last_message
      path = Routes.support_index_path(socket, :show, user_id)
      push_patch(socket, to: path, replace: true)
    else
      socket
    end
  end

  defp apply_action(%{"user_id" => user_id}, :show, socket) do
    case Support.list_messages(user_id) do
      [] ->
        path = Routes.support_index_path(socket, :index)
        push_patch(socket, to: path, replace: true)

      messages ->
        assign(socket, messages: messages, user_id: user_id)
    end
  end

  @impl true
  def handle_info({Support, [:message, :created], message}, socket) do
    side_panel = update_side_panel(socket.assigns.side_panel, message)
    socket = assign(socket, side_panel: side_panel)

    socket =
      if message.user_id == socket.assigns.user_id do
        assign(socket, messages: [message])
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("send-message", %{"message" => %{"text" => text}}, socket) do
    if user_id = socket.assigns.user_id do
      {:ok, message} =
        Support.add_message(user_id, admin_id(), %{"kind" => "text", "data" => %{"text" => text}})

      TWeb.Endpoint.broadcast!(
        "support:#{user_id}",
        "message:new",
        %{message: TWeb.MessageView.render("show.json", %{message: message})}
      )
    end

    {:noreply, socket}
  end

  defp build_side_panel(messages) do
    messages
  end

  defp update_side_panel(side_panel, new_message) do
    %Support.Message{user_id: user_id} = new_message

    if Enum.find(side_panel, fn p -> p.user_id == user_id end) do
      Enum.map(side_panel, fn m ->
        if m.user_id == user_id do
          new_message
        else
          m
        end
      end)
    else
      [new_message | side_panel]
    end
  end

  defp render_message(%Support.Message{kind: "text", data: %{"text" => text}}) do
    text
  end

  defp render_message(%Support.Message{kind: "photo", data: %{"s3_key" => s3_key}}) do
    ~E"""
    <img src="<%= Media.user_imgproxy_cdn_url(s3_key) %>" class="w-64 mt-2 border border-gray-800 rounded" />
    """
  end

  defp render_message(%Support.Message{kind: "audio", data: %{"s3_key" => s3_key}}) do
    ~E"""
    <audio src="<%= Media.user_s3_url(s3_key) %>" controls class="mt-2" />
    """
  end

  defp render_side_panel_message(%Support.Message{kind: "text", data: %{"text" => text}}) do
    text
  end

  defp render_side_panel_message(%Support.Message{kind: "photo"}) do
    "*photo*"
  end

  defp render_side_panel_message(%Support.Message{kind: "audio"}) do
    "*audio*"
  end

  @admin_id "00000000-0000-4000-0000-000000000000"
  defp render_author(@admin_id), do: ~E[<span class="text-green-400">admin</span>]
  defp render_author(_user_id), do: ~E[<span class="text-yellow-400">user</span>]

  defp admin_id, do: @admin_id
end
