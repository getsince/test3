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
  # support:<user-id>
  channel "support:*", TWeb.SupportChannel
  # # user:<uuid>
  # channel "user:*", TWeb.UserChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    if user = Accounts.get_user_by_session_token(token, "mobile") do
      {:ok, assign(socket, current_user: user, token: token)}
    else
      # TODO return reason (like user deleted, or invalid token)
      :error
    end
  end

  def connect(_params, _socket, _connect_info) do
    :error
  end

  defoverridable init: 1

  @impl true
  def init(state) do
    res = {:ok, {_, socket}} = super(state)
    on_connect(self(), socket.assigns.current_user)
    res
  end

  @impl true
  def id(socket) do
    token = Accounts.UserToken.encoded_token(socket.assigns.token)
    "user_socket:#{token}"
  end

  # TODO test
  defp on_connect(pid, user) do
    __MODULE__.Monitor.monitor(pid, user.id)
  end
end
