defmodule T.PushNotifications.APNSJob do
  @moduledoc false

  use Oban.Worker, queue: :apns, max_attempts: 5
  alias T.Accounts
  require Logger

  @impl true
  def perform(%Oban.Job{args: args}) do
    %{"template" => template, "data" => data, "device_id" => device_id} = args

    topic = args["topic"] || T.PushNotifications.APNS.default_topic()
    push_type = args["push_type"]
    priority = args["priority"]

    payload =
      if push_type == "background" do
        T.PushNotifications.APNS.background_notification_payload(template, data)
      else
        Gettext.with_locale(args["locale"] || "en", fn ->
          T.PushNotifications.APNS.build_alert_payload(template, data)
        end)
      end

    env = T.PushNotifications.APNS.apns_env(args["env"])

    device_id
    |> APNS.build_notification(topic, payload, env, push_type, priority)
    |> T.PushNotifications.APNS.push()
    |> case do
      :ok ->
        :ok

      {:error, reason} when reason in [:bad_device_token, :unregistered] ->
        Logger.warn("removing apns_device=#{device_id} due to receving '#{reason}' for it")
        Accounts.remove_apns_device(device_id)
        :discard

      {:error, _reason} = other ->
        other
    end
  end
end
