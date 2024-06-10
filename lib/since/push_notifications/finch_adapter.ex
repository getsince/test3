defmodule Since.PushNotifications.APNS.FinchAdapter do
  @moduledoc false
  @behaviour T.PushNotifications.APNS.Adapter

  @impl true
  @spec push(APNS.notification()) :: APNS.response()
  def push(notification), do: APNS.push(notification, T.Finch)
end
