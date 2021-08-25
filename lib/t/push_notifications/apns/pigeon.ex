defmodule T.PushNotifications.APNS.Pigeon do
  @moduledoc false
  @behaviour T.PushNotifications.APNS.Adapter
  alias Pigeon.APNS

  @impl true
  @spec push(%APNS.Notification{}, :dev | :prod) :: %APNS.Notification{}
  @spec push([%APNS.Notification{}], :dev | :prod) :: [%APNS.Notification{}]
  def push(notifications, env) when env in [:dev, :prod] do
    APNS.push(notifications, to: env)
  end
end
