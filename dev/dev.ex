defmodule Dev do
  # alias T.PushNotifications.APNS

  # def attach do
  #   detach()

  #   :telemetry.attach_many(
  #     "test-handler",
  #     [[:phoenix, :endpoint, :stop], [:phoenix, :router_dispatch, :stop]],
  #     fn event, measurements, metadata, config ->
  #       IO.inspect(event: event, measurements: measurements, metadata: metadata, config: config)
  #     end,
  #     _config = nil
  #   )
  # end

  # def detach do
  #   :telemetry.detach("test-handler")
  # end

  # def send_notification(locale \\ "en") do
  #   device_id = System.get_env("MY_APNS_ID")

  #   n =
  #     Gettext.with_locale(locale, fn ->
  #       APNS.build_notification("timeslot_started", device_id, %{})
  #     end)

  #   APNS.push(n)
  # end
end
