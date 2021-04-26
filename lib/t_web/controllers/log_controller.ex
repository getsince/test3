defmodule TWeb.LogController do
  use TWeb, :controller
  require Logger

  def log(conn, params) do
    Logger.info(["ios: ", inspect(params)])
    send_resp(conn, 200, [])
  end
end
