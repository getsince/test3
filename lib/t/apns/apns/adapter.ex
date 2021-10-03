defmodule T.PushNotifications.APNS.Adapter do
  @callback push(n, :dev | :prod) :: n when n: Notification.t() | [Notification.t()]
end
