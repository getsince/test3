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

  def pushkit_call(device_id, payload) when is_binary(device_id) do
    push_all_envs(%Notification{
      device_token: device_id,
      topic: topic() <> ".voip",
      push_type: "voip",
      expiration: 0,
      payload: payload
    })
  end

  def pushkit_call(device_ids, payload) when is_list(device_ids) do
    Enum.map(device_ids, fn id -> pushkit_call(id, payload) end)
  end
end
