defmodule Since.PushNotifications.APNS.Adapter do
  @moduledoc false
  @callback push(APNS.notification()) :: APNS.response()
end
