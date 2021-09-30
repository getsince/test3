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

    if user = Accounts.get_user_by_session_token(token, "mobile") do
      Logger.metadata(user_id: user.id)
      Logger.warn("user online #{user.id}")

      # TODO remove
      Accounts.update_last_active(user.id)

      {:ok,
       assign(socket,
         current_user: user,
         token: token,
         screen_width: params["screen_width"] || 1000,
         version: extract_version(params)
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

  defp extract_version(params) do
    if version = params["version"] do
      case Version.parse(version) do
        {:ok, version} -> version
        :error -> nil
      end
    end || %Version{major: 1, minor: 0, patch: 0}
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
