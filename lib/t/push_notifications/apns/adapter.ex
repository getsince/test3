defmodule T.PushNotifications.APNS.Adapter do
  alias Pigeon.APNS.Notification

  @callback push(Notification.t(), env :: :prod | :dev) :: Notification.t()
  @callback push([Notification.t()], env :: :prod | :dev) :: [Notification.t()]
end
