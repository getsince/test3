defmodule TWeb.MobileAuthController do
  use TWeb, :controller
  alias T.Accounts

  def request_sms(conn, %{"phone_number" => phone_number}) do
    case Accounts.deliver_user_confirmation_instructions(phone_number) do
      {:ok, _sent} -> send_resp(conn, 201, [])
      # TODO
      {:error, :invalid_phone_number} -> send_resp(conn, 400, [])
    end
  end

  def verify_phone_number(conn, %{"phone_number" => phone_number, "code" => code}) do
    case Accounts.login_or_register_user(phone_number, code) do
      {:ok, user} ->
        TWeb.UserAuth.log_in_mobile_user(conn, user)

      {:error, _reason} ->
        # TODO
        send_resp(conn, 400, [])
    end
  end
end
