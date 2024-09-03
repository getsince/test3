defmodule SinceWeb.AppStoreNotificationController do
  use SinceWeb, :controller

  require Logger

  def process_app_store_notification(conn, params) do
    Logger.warning(params)
    {_, notification} = Enum.find(params, fn {key, _} -> key == "signedPayload" end)
    AppStore.process_notification(notification)

    send_resp(conn, 200, [])
  end
end
