defmodule TWeb.DeviceController do
  use TWeb, :controller

  alias TWeb.UserAuth
  alias T.Accounts

  def create_ios_token(conn, %{"device_token" => device_token} = params) do
    device_token = Base.decode64!(device_token)
    {user_id, user_token, env} = user_info(conn)

    :ok =
      Accounts.save_apns_device_id(user_id, user_token, device_token,
        locale: params["locale"],
        env: env
      )

    send_resp(conn, 201, [])
  end

  # TODO remove
  def create_push_token(conn, _params) do
    send_resp(conn, 201, [])
  end

  defp user_info(conn) do
    %{current_user: user} = conn.assigns
    user_token = UserAuth.bearer_token(conn)
    {user.id, user_token, user_env(conn)}
  end

  defp user_env(conn) do
    case get_req_header(conn, "x-apns-env") do
      [env] when env in ["prod", "sandbox"] -> env
      [] -> nil
    end
  end
end
