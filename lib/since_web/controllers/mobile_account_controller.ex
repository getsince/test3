defmodule SinceWeb.MobileAccountController do
  use SinceWeb, :controller
  alias Since.Accounts

  def delete(conn, params) do
    reason = params["reason"]
    %Accounts.User{} = user = conn.assigns.current_user
    {:ok, %{session_tokens: tokens}} = Accounts.delete_user(user.id, reason)

    for token <- tokens do
      encoded = Accounts.UserToken.encoded_token(token)
      SinceWeb.Endpoint.broadcast("user_socket:#{encoded}", "disconnect", %{})
    end

    send_resp(conn, 200, [])
  end
end
