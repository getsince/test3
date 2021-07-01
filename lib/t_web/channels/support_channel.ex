defmodule TWeb.SupportChannel do
  use TWeb, :channel
  alias TWeb.{ErrorView, MessageView}
  alias T.{Support, Matches}

  @impl true
  def join("support:" <> user_id, params, socket) do
    user_id = ChannelHelpers.verify_user_id(socket, user_id)

    # TODO admins can join too?
    messages =
      if last_message_id = params["last_message_id"] do
        Support.list_messages(user_id, after: last_message_id)
      else
        Support.list_messages(user_id)
      end

    {:ok, %{messages: render_messages(messages)}, socket}
  end

  defp render_messages(messages) do
    Enum.map(messages, &render_message/1)
  end

  defp render_message(message) do
    render(MessageView, "show.json", message: message)
  end

  @impl true
  def handle_in("message", %{"message" => params}, socket) do
    %{current_user: user} = socket.assigns

    case Support.add_message(user.id, user.id, params) do
      {:ok, message} ->
        broadcast!(socket, "message:new", %{message: render_message(message)})
        {:reply, :ok, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:reply, {:error, %{message: render(ErrorView, "changeset.json", changeset: changeset)}},
         socket}
    end
  end

  def handle_in("upload-preflight", %{"media" => params}, socket) do
    content_type =
      case params do
        %{"content-type" => content_type} -> content_type
        %{"extension" => extension} -> MIME.type(extension)
      end

    # TODO
    {:ok, %{"key" => key} = fields} = Matches.media_upload_form(content_type)
    url = Matches.media_s3_url()

    uploads = socket.assigns[:uploads] || %{}
    socket = assign(socket, uploads: Map.put(uploads, key, nil))

    # TODO check key afterwards
    {:reply, {:ok, %{url: url, key: key, fields: fields}}, socket}
  end
end
