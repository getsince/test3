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

  def args do
    %{
      "data" => %{
        "match_id" => "0000017b-b277-cbad-0242-ac1100020000"
      },
      "device_id" => "E069BD8A7CFF5BC34656C767209697AE3DB3B26E03E1252FA79EA7A773F75783",
      "env" => "sandbox",
      "locale" => nil,
      "template" => "timeslot_started",
      "topic" => "since.app.ios"
    }
  end

  def send_notification(args \\ args()) do
    T.PushNotifications.APNSJob.perform(%Oban.Job{args: args})
  end
end
