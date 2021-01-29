defmodule TWeb.MatchChannel do
  use TWeb, :channel
  alias TWeb.{ErrorView, MatchView}
  alias T.{Matches, Accounts}

  @impl true
  def join("match:" <> match_id, params, socket) do
    if match = Matches.get_current_match(socket.assigns.current_user.id) do
      if match.id == match_id do
        # match_user_ids = [match.user_id_1, match.user_id_2]
        # ChannelHelpers.verify_user_id(socket, match_user_ids)
        # other_user_id = ChannelHelpers.other_user_id(socket, match_user_ids)
        # TODO
        # other_user_online? = ChannelHelpers.user_online?(other_user_id)
        # Matches.subscribe(match.id)

        # TODO paginate
        messages =
          if last_message_id = params["last_message_id"] do
            Matches.list_messages(match_id, after: last_message_id)
          else
            Matches.list_messages(match_id)
          end

        # TODO get latest messages read, latest timestamp, and fetch
        {:ok, %{messages: render_messages(messages)}, assign(socket, match: match)}
      end
    end || {:error, socket}
  end

  defp render_messages(messages) do
    Enum.map(messages, &render_message/1)
  end

  defp render_message(message) do
    render(MatchView, "message.json", message: message)
  end

  @impl true
  def handle_in("message", %{"message" => params}, socket) do
    %{match: match, current_user: user} = socket.assigns

    case Matches.add_message(match.id, user.id, params) do
      {:ok, message} ->
        broadcast_from!(socket, "message:new", %{message: render_message(message)})
        {:reply, :ok, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:reply, {:error, %{message: render(ErrorView, "changeset.json", changeset: changeset)}},
         socket}
    end
  end

  # def handle_in("fetch", params, socket) do
  #   # TODO fetch messages
  # end

  # TODO message read
  # def handle_in("")

  def handle_in("unmatch", _params, socket) do
    %{match: match, current_user: user} = socket.assigns
    # TODO reply here that we have another match?
    {:ok, _changes} = Matches.unmatch(user.id, match.id)
    broadcast_from!(socket, "unmatched", %{})
    {:reply, :ok, socket}
  end

  def handle_in("upload-preflight", %{"media" => params}, socket) do
    content_type =
      case params do
        %{"content-type" => content_type} -> content_type
        %{"extension" => extension} -> MIME.type(extension)
      end

    {:ok, %{"key" => key} = fields} = Matches.media_upload_form(content_type)
    url = Matches.media_s3_url()

    uploads = socket.assigns[:uploads] || %{}
    socket = assign(socket, uploads: Map.put(uploads, key, nil))

    # TODO check key afterwards
    {:reply, {:ok, %{url: url, key: key, fields: fields}}, socket}
  end

  # TODO test
  def handle_in("report", %{"report" => %{"reason" => reason}}, socket) do
    %{current_user: reporter, match: match} = socket.assigns
    match_user_ids = [match.user_id_1, match.user_id_2]
    reported_user_id = ChannelHelpers.other_user_id(socket, match_user_ids)

    case Accounts.report_user(reporter.id, reported_user_id, reason) do
      :ok ->
        {:reply, :ok, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:reply, {:error, %{report: render(ErrorView, "changeset.json", changeset: changeset)}},
         socket}
    end
  end

  # TODO
  # def handle_in("media:uploaded", _params, socket) do
  #   {:reply, :ok, socket}
  # end
end
