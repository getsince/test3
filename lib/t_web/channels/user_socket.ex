defmodule TWeb.UserSocket do
  use Phoenix.Socket
  require Logger
  alias T.Accounts
  alias __MODULE__.Monitor

  # feed:<user-id>
  channel "feed:*", TWeb.FeedChannel
  # profile:<user-id>
  channel "profile:*", TWeb.ProfileChannel

  @impl true
  @spec connect(any, any, any) :: :error | {:ok, Phoenix.Socket.t()}
  def connect(%{"token" => token} = params, socket, connect_info) do
    if remote_ip = extract_ip_address(connect_info) do
      Logger.metadata(remote_ip: remote_ip)
    end

    version = params["version"]
    ios_version = if version, do: "ios/" <> version

    if user = Accounts.get_user_by_session_token_and_update_version(token, ios_version, "mobile") do
      Logger.metadata(user_id: user.id)
      Logger.warn("user online #{user.id}")
      Accounts.update_last_active(user.id)

      location = maybe_location(params)
      if location, do: Accounts.update_location(user.id, location)

      if check_version(version) do
        {:ok,
         assign(socket,
           current_user: user,
           token: token,
           screen_width: params["screen_width"] || 1000,
           locale: params["locale"],
           version: version,
           location: location
         )}
      else
        Accounts.schedule_upgrade_app_push(user.id)
        {:error, :unsupported_version}
      end
    else
      # TODO return reason (like user deleted, or invalid token)
      :error
    end
  end

  def connect(_params, _socket, _connect_info) do
    :error
  end

  defp maybe_location(%{"location" => [lat, lon]} = _params) do
    %Geo.Point{coordinates: {lon, lat}, srid: 4326}
  end

  defp maybe_location(_params), do: nil

  defp check_version(nil), do: false
  defp check_version(version), do: Version.match?(version, ">= 6.0.0")

  def handle_error(conn, :unsupported_version),
    do: Plug.Conn.send_resp(conn, 418, "")

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

    Monitor.monitor(
      pid,
      _on_disconnect = fn ->
        Accounts.update_last_active(user_id)
        Logger.warn("user offline #{user_id}")
      end
    )
  end
end
