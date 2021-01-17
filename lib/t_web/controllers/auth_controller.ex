defmodule TWeb.AuthController do
  use TWeb, :controller

  # # TODO params
  # def me(conn, _params) do
  #   token = get_session(conn, :user_token)
  #   %T.Accounts.User{id: user_id} = user = T.Accounts.get_user_by_session_token(token)

  #   json(conn, %{
  #     me: user_id,
  #     next: next(user),
  #     token: Phoenix.Token.sign(conn, "Urm6JRcI", user_id)
  #   })
  # end

  # defp next(user) do
  #   cond do
  #     blocked?(user) -> "blocked"
  #     not onboarded?(user) -> "onboarding"
  #     true -> "main"
  #   end
  # end

  # defp blocked?(%T.Accounts.User{blocked_at: blocked_at}) do
  #   not is_nil(blocked_at)
  # end

  # defp onboarded?(%T.Accounts.User{onboarded_at: onboarded_at}) do
  #   not is_nil(onboarded_at)
  # end
end
