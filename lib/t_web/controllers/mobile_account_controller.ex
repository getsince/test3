defmodule TWeb.MobileAccountController do
  use TWeb, :controller
  alias T.Accounts

  def delete(conn, _params) do
    %Accounts.User{} = user = conn.assigns.current_user
    {:ok, %{delete_sessions: tokens}} = Accounts.delete_user(user.id)

    for token <- tokens do
      encoded = Accounts.UserToken.encoded_token(token)
      TWeb.Endpoint.broadcast("user_socket:#{encoded}", "disconnect", %{})
    end

    send_resp(conn, 200, [])
  end
end
