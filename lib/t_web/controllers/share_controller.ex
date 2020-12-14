defmodule TWeb.ShareController do
  use TWeb, :controller

  action_fallback TWeb.FallbackController

  def email(conn, %{"email" => email}) do
    with {:ok, _email} <- T.Share.save_email(email) do
      send_resp(conn, 201, [])
    end
  end

  def phone(conn, %{"phone" => phone} = attrs) do
    meta =
      (attrs["meta"] || %{})
      |> Map.put("ip", conn.remote_ip |> :inet.ntoa() |> to_string())
      |> Map.put("user-agent", conn |> get_req_header("user-agent") |> List.first())

    attrs =
      attrs
      |> Map.put("phone_number", phone)
      |> Map.put("meta", meta)

    with {:ok, _phone} <- T.Share.save_phone(attrs) do
      send_resp(conn, 201, [])
    end
  end
end
