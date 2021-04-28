defmodule T.PushNotifications.APNS do
  @moduledoc false
  alias Pigeon.APNS.Notification
  alias Pigeon.APNS

  def push_all_envs(%Notification{} = n) do
    Application.fetch_env!(:pigeon, :apns)
    |> Enum.map(fn {worker, _} -> APNS.push(n, to: worker) end)
    |> case do
      [n] -> n
      [%Notification{response: :success} = n, _n] -> n
      [_n, %Notification{response: :success} = n] -> n
      [_, _] = fails -> fails
    end
    |> List.wrap()
  end

  defp topic do
    Application.fetch_env!(:pigeon, :apns)[:apns_default].topic
  end

  def base_notification(device_id, collapse_id) do
    %Notification{
      device_token: device_id,
      topic: topic(),
      # TODO thread id
      collapse_id: collapse_id
    }
  end

  def put_tab(notification, tab) do
    notification
    |> Notification.put_mutable_content()
    |> Notification.put_custom(%{"tab" => tab})
  end
end
