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
    case Accounts.login_or_register_user_with_phone(phone_number, code) do
      {:ok, user} ->
        verification_success_response(conn, user)

      {:error, _reason} ->
        # TODO
        send_resp(conn, 400, [])
    end
  end

  def verify_apple_id(conn, %{"token" => base64_id_token}) do
    id_token = Base.decode64!(base64_id_token)

    case Accounts.login_or_register_user_with_apple_id(id_token) do
      {:ok, %Accounts.User{} = user} -> verification_success_response(conn, user)
      {:error, _reason} -> send_resp(conn, 400, [])
    end
  end

  defp verification_success_response(conn, user) do
    token = Accounts.generate_user_session_token(user, "mobile")

    conn
    |> put_status(200)
    |> json(%{
      token: Accounts.UserToken.encoded_token(token),
      user: render_user(user),
      # TODO proper screen_width
      profile:
        TWeb.ProfileView.render("show_with_location.json",
          profile: user.profile,
          screen_width: 1000
        )
    })
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
