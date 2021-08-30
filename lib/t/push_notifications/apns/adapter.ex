defmodule T.PushNotifications.APNS.Adapter do
  alias Pigeon.APNS.Notification

  @callback push(n, :dev | :prod) :: n when n: Notification.t() | [Notification.t()]
end
