defmodule Since.PushNotifications.APNS.FinchAdapter do
  @moduledoc false
  @behaviour Since.PushNotifications.APNS.Adapter

  @impl true
  @spec push(APNS.notification()) :: APNS.response()
  def push(notification), do: APNS.push(notification, Since.Finch)
end
