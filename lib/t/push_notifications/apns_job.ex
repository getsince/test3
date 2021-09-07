defmodule T.PushNotifications.APNSJob do
  @moduledoc false

  use Oban.Worker, queue: :apns, max_attempts: 5
  alias T.{PushNotifications.APNS, Accounts, Accounts.APNSDevice}
  alias Pigeon.APNS.Notification

  @impl true
  def perform(%Oban.Job{args: args}) do
    %{"template" => template, "data" => data, "device_id" => device_id} = args

    device = %APNSDevice{
      device_id: device_id,
      env: args["env"],
      topic: args["topic"],
      locale: args["locale"]
    }

    case APNS.push_alert(template, device, data) do
      %Notification{response: :success} ->
        :ok

      %Notification{response: response, device_token: device_id}
      when response in [:bad_device_token, :unregistered] ->
        Accounts.remove_apns_device(device_id)
        :discard
    end
  end
end
