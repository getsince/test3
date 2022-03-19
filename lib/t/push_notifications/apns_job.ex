defmodule T.PushNotifications.APNSJob do
  @moduledoc false

  use Oban.Worker, queue: :apns, max_attempts: 5

  alias T.Accounts
  alias T.PushNotifications.APNS, as: Pushes

  require Logger

  @impl true
  def perform(%Oban.Job{args: args}) do
    %{"template" => template, "data" => data, "device_id" => device_id} = args

    topic = args["topic"] || Pushes.default_topic()
    env = Pushes.apns_env(args["env"])

    payload =
      Gettext.with_locale(args["locale"] || "en", fn ->
        Pushes.build_alert_payload(template, data)
      end)

    device_id
    |> APNS.build_notification(topic, payload, env)
    |> Pushes.push()
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

  @impl true
  def timeout(_job), do: :timer.seconds(5)
end
