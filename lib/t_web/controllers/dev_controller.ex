defmodule TWeb.DevController do
  use TWeb, :controller

  def get_phone_code(conn, %{"phone" => phone}) do
    state = Agent.get(PasswordlessAuth.Store, fn state -> state end)
    json(conn, %{"code" => state[phone].code})
  end
end
