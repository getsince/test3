defmodule T.PushNotifications.APNSJob do
  @moduledoc false

  use Oban.Worker, queue: :apns, max_attempts: 5
  alias T.{APNS, Accounts}

  @impl true
  def perform(%Oban.Job{args: args}) do
    %{"template" => template, "data" => data, "device_id" => device_id} = args

    device = %Accounts.APNSDevice{
      device_id: device_id,
      env: args["env"],
      topic: args["topic"],
      locale: args["locale"]
    }

    case APNS.push_templated_alert(template, device, data) do
      :ok = ok ->
        ok

      {:error, reason} when reason in [:bad_device_token, :unregistered] ->
        Accounts.remove_apns_device(device_id)
        :discard

      {:error, _other} = error ->
        error
    end
  end
end
