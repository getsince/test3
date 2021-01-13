defmodule TWeb.AuthController do
  use TWeb, :controller

  def request_sms(conn, %{"phone_number" => phone_number}) do
    case T.Accounts.deliver_user_confirmation_instructions(phone_number) do
      {:ok, _sent} -> send_resp(conn, 201, [])
      # TODO
      {:error, :invalid_phone_number} -> send_resp(conn, 400, [])
    end
  end

  def verify_phone_number(conn, %{"phone_number" => phone_number, "code" => code}) do
    case T.Accounts.login_or_register_user(phone_number, code) do
      {:ok, user} ->
        TWeb.UserAuth.log_in_phone_user(conn, user)

      {:error, _reason} ->
        # TODO
        send_resp(conn, 400, [])
    end
  end

  # TODO params
  def me(conn, _params) do
    token = get_session(conn, :user_token)
    %T.Accounts.User{id: user_id} = user = T.Accounts.get_user_by_session_token(token)

    json(conn, %{
      me: user_id,
      next: next(user),
      token: Phoenix.Token.sign(conn, "Urm6JRcI", user_id)
    })
  end

  defp next(user) do
    cond do
      blocked?(user) -> "blocked"
      not onboarded?(user) -> "onboarding"
      true -> "main"
    end
  end

  defp blocked?(%T.Accounts.User{blocked_at: blocked_at}) do
    not is_nil(blocked_at)
  end

  defp onboarded?(%T.Accounts.User{onboarded_at: onboarded_at}) do
    not is_nil(onboarded_at)
  end
end
