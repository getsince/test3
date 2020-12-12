defmodule TWeb.ShareController do
  use TWeb, :controller

  action_fallback TWeb.FallbackController

  def email(conn, %{"email" => email}) do
    with {:ok, _email} <- T.Share.save_email(email) do
      send_resp(conn, 201, [])
    end
  end

  def phone(conn, %{"phone" => phone}) do
    with {:ok, _phone} <- T.Share.save_phone(phone) do
      send_resp(conn, 201, [])
    end
  end
end
