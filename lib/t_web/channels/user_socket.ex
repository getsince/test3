defmodule TWeb.UserSocket do
  use Phoenix.Socket
  alias T.Accounts

  # feed:<uuid>
  channel "feed:*", TWeb.FeedChannel
  # match:<uuid>:<uuid>
  channel "match:*", TWeb.MatchChannel
  # profile:<uuid>
  channel "profile:*", TWeb.ProfileChannel
  # notification:<uuid>
  channel "notification:*", TWeb.NotificationChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    token = Base.decode64!(token, padding: false)

    if user = Accounts.get_user_by_session_token(token) do
      {:ok, assign(socket, current_user: user, token: token)}
    else
      :error
    end
  end

  def connect(_params, _socket, _connect_info) do
    :error
  end

  @impl true
  def id(socket) do
    "user_socket:#{socket.assigns.token}"
  end
end
