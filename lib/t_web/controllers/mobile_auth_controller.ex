defmodule TWeb.MobileAuthController do
  use TWeb, :controller
  alias TWeb.UserAuth
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
        token = Accounts.generate_user_session_token(user, "mobile")

        conn
        |> put_status(200)
        |> json(%{
          token: Accounts.UserToken.encoded_token(token),
          user: render_user(user),
          profile: TWeb.ProfileView.render("show.json", profile: user.profile)
        })

      {:error, _reason} ->
        # TODO
        send_resp(conn, 400, [])
    end
  end

  def delete(conn, _params) do
    if token = UserAuth.bearer_token(conn) do
      :ok = UserAuth.log_out_mobile_user(token)
      send_resp(conn, 200, [])
    else
      send_resp(conn, 404, [])
    end
  end

  defp render_user(user) do
    %Accounts.User{id: id, blocked_at: blocked_at, onboarded_at: onboarded_at} = user
    %{id: id, blocked_at: blocked_at, onboarded_at: onboarded_at}
  end
end
