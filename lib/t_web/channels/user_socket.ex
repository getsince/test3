defmodule TWeb.UserSocket do
  use Phoenix.Socket
  alias T.Accounts

  # feed:<user-id>
  channel "feed:*", TWeb.FeedChannel
  # match:<match-id>
  channel "match:*", TWeb.MatchChannel
  # profile:<user-id>
  channel "profile:*", TWeb.ProfileChannel
  # notification:<user-id>
  channel "notification:*", TWeb.NotificationChannel
  # # user:<uuid>
  # channel "user:*", TWeb.UserChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    if user = Accounts.get_user_by_session_token(token, "mobile") do
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
    token = Accounts.UserToken.encoded_token(socket.assigns.token)
    "user_socket:#{token}"
  end
end
