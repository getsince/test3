defmodule T.PushNotifications.APNS.Pigeon do
  @moduledoc false
  @behaviour T.PushNotifications.APNS.Adapter
  alias Pigeon.APNS
  alias Pigeon.APNS.Notification

  @impl true
  @spec push(n, :dev | :prod) :: n when n: Notification.t() | [Notification.t()]
  def push(notifications, env) when env in [:dev, :prod] do
    APNS.push(notifications, to: env)
  end
end
