defmodule TWeb.UserSocket do
  use Phoenix.Socket
  require Logger
  alias T.Accounts
  alias __MODULE__.Monitor

  # feed:<user-id>
  channel "feed:*", TWeb.FeedChannel
  # call:<call-id>
  channel "call:*", TWeb.CallChannel
  # profile:<user-id>
  channel "profile:*", TWeb.ProfileChannel
  # admin
  channel "admin", TWeb.AdminChannel

  @impl true
  def connect(%{"token" => token} = params, socket, connect_info) do
    if remote_ip = extract_ip_address(connect_info) do
      Logger.metadata(remote_ip: remote_ip)
    end

    version = if version = params["version"], do: "ios/" <> version

    if user = Accounts.get_user_by_session_token_and_update_version(token, version, "mobile") do
      Logger.metadata(user_id: user.id)
      Logger.warn("user online #{user.id}")
      Accounts.update_last_active(user.id)

      {:ok,
       assign(socket,
         current_user: user,
         token: token,
         screen_width: params["screen_width"] || 1000
       )}
    else
      # TODO return reason (like user deleted, or invalid token)
      :error
    end
  end

  def connect(_params, _socket, _connect_info) do
    :error
  end

  defp extract_ip_address(connect_info) do
    _extract_ip_address(:x_headers, connect_info) ||
      _extract_ip_address(:peer_data, connect_info)
  end

  defp _extract_ip_address(:x_headers, %{x_headers: x_headers}) do
    :proplists.get_value("x-forwarded-for", x_headers, nil)
  end

  defp _extract_ip_address(:peer_data, %{peer_data: %{address: address}}) do
    :inet.ntoa(address)
  end

  defp _extract_ip_address(_key, _connect_info), do: nil

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
  defp on_connect(pid, current_user) do
    %Accounts.User{id: user_id} = current_user

    # TODO not needed anymore (now that we have active sessions)
    Monitor.monitor(
      pid,
      _on_disconnect = fn ->
        Accounts.update_last_active(user_id)
        Logger.warn("user offline #{user_id}")
      end
    )
  end
end
