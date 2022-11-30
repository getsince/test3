defmodule TWeb.AppStoreNotificationController do
  use TWeb, :controller

  require Logger

  def process_app_store_notification(conn, params) do
    Logger.warn(params)
    {_, notification} = Enum.find(params, fn {key, _} -> key == "signedPayload" end)
    AppStore.process_notification(notification)

    send_resp(conn, 200, [])
  end
end
