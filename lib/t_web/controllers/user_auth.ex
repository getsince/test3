defmodule TWeb.UserAuth do
  import Plug.Conn
  import Phoenix.Controller
  require Logger

  alias T.Accounts

  def log_out_mobile_user(token, context \\ "mobile") do
    decoded_token = Accounts.UserToken.raw_token(token)
    encoded_token = Accounts.UserToken.encoded_token(token)

    Accounts.delete_session_token(decoded_token, context)
    TWeb.Endpoint.broadcast("user_socket:#{encoded_token}", "disconnect", %{})

    :ok
  end

  def fetch_current_user_from_bearer_token(conn, _opts) do
    user =
      if token = bearer_token(conn) do
        token = Accounts.UserToken.raw_token(token)
        Accounts.get_user_by_session_token(token, "mobile")
      end

    if user do
      Logger.metadata(user_id: user.id)
    end

    assign(conn, :current_user, user)
  end

  def bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> token
      [] -> nil
    end
  end

  @doc """
  Used for routes that require the user to not be authenticated.
  """
  def require_not_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> put_status(400)
      |> json(%{detail: "You are already authenticated."})
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that require the user to be authenticated.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_status(401)
      |> json(%{detail: "You must log in to access this resource."})
      |> halt()
    end
  end

  def dashboard_auth(conn, _opts) do
    dashboard_auth_opts = Application.fetch_env!(:t, :dashboard)
    Plug.BasicAuth.basic_auth(conn, dashboard_auth_opts)
  end
end
