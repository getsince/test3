defmodule TWeb.DeviceController do
  use TWeb, :controller
  alias TWeb.UserAuth
  alias T.Accounts

  # TODO test
  def create_ios_token(conn, %{"device_token" => device_token}) do
    device_token = Base.decode64!(device_token)
    %{current_user: user} = conn.assigns
    user_token = UserAuth.bearer_token(conn)
    :ok = Accounts.save_apns_device_id(user.id, user_token, device_token)
    send_resp(conn, 201, [])
  end
end
