defmodule TWeb.InAppPurchaseController do
  use TWeb, :controller

  require Logger

  def process_ios_in_app_purchase_update(conn, params) do
    Logger.warn(params)

    send_resp(conn, 201, [])
  end
end
