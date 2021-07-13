defmodule T.PushNotifications.APNSJob do
  @moduledoc false

  use Oban.Worker, queue: :apns, max_attempts: 5
  alias T.PushNotifications.APNS
  alias Pigeon.APNS.Notification

  @impl true
  def perform(%Oban.Job{args: args}) do
    %{"template" => template, "device_id" => device_id, "data" => data} = args

    n =
      Gettext.with_locale(args["locale"] || "en", fn ->
        APNS.build_notification(template, device_id, data)
      end)

    APNS.push_all_envs(n)
    |> Enum.reduce([], fn %Notification{response: r, device_token: device_id}, acc ->
      if r in [:bad_device_token, :unregistered] do
        T.Accounts.remove_apns_device(device_id)
      end

      if r == :success do
        :ok
      else
        acc
      end
    end)
    |> case do
      :ok -> :ok
      [] -> :discard
    end
  end
end
