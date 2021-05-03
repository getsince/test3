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

  defp base_notification(device_id, type, data) do
    %Notification{
      device_token: device_id,
      topic: topic(),
      # TODO repalce with thread id, possibly remove collapse id
      collapse_id: type
    }
    # TODO is this needed?
    |> Notification.put_mutable_content()
    |> Notification.put_custom(%{"type" => type})
    |> Notification.put_custom(data)
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

  defp put_tab(notification, tab) do
    notification
    |> Notification.put_mutable_content()
    |> Notification.put_custom(%{"tab" => tab})
  end

  def build_notification("match", device_id, data) do
    title = "Твоя симпатия взаимна 🎉"
    body = "Скорее заходи!"

    base_notification(device_id, "match", data)
    |> Notification.put_alert(%{"title" => title, "body" => body})
    |> Notification.put_badge(1)
    |> put_tab("matches")
  end

  def build_notification("yo", device_id, data) do
    %{"title" => title, "body" => body, "ack_id" => ack_id} = data

    base_notification(device_id, "yo", %{"ack_id" => ack_id})
    |> Notification.put_alert(%{"title" => title, "body" => body})
    |> Notification.put_badge(1)
    |> put_tab("matches")
  end

  def build_notification("message", device_id, data) do
    title = "Тебе отправили сообщение ;)"
    body = "Не веришь? Проверь"

    base_notification(device_id, "message", data)
    |> Notification.put_alert(%{"title" => title, "body" => body})
    |> Notification.put_badge(1)
    |> put_tab("matches")
  end

  def build_notification("support", device_id, data) do
    title = "Пссс..."
    body = "Сообщение от поддержки 🌚"

    base_notification(device_id, "support", data)
    |> Notification.put_alert(%{"title" => title, "body" => body})
    |> Notification.put_badge(1)
    |> put_tab("support")
  end

  def build_notification("timeslot_offer", device_id, data) do
    title = "Тили-тили тесто"
    body = "Тебя на свиданку пригласили"

    base_notification(device_id, "timeslot_offer", data)
    |> Notification.put_alert(%{"title" => title, "body" => body})
    |> Notification.put_badge(1)
    |> put_tab("dates")
  end

  def build_notification("timeslot_accepted", device_id, data) do
    title = "Тили-тили тесто"
    body = "У кого-то свиданочка намечается"

    base_notification(device_id, "timeslot_accepted", data)
    |> Notification.put_alert(%{"title" => title, "body" => body})
    |> Notification.put_badge(1)
    |> put_tab("dates")
  end

  def build_notification("timeslot_cancelled", device_id, data) do
    title = "Дейт отменён"
    body = "Тебя больше не хотят видеть"

    base_notification(device_id, "timeslot_cancelled", data)
    |> Notification.put_alert(%{"title" => title, "body" => body})
    |> Notification.put_custom(data)
    |> Notification.put_badge(1)
    |> put_tab("dates")
  end

  def build_notification("timeslot_reminder", device_id, data) do
    title = "Скоро свиданочка"
    body = "Приготовься, у тебя 15 минут"

    base_notification(device_id, "timeslot_reminder", data)
    |> Notification.put_alert(%{"title" => title, "body" => body})
    |> Notification.put_badge(1)
    |> put_tab("dates")
  end

  def build_notification("timeslot_started", device_id, data) do
    title = "Свидангу начинается"
    body = "Скорее заходи!"

    base_notification(device_id, "timeslot_started", data)
    |> Notification.put_alert(%{"title" => title, "body" => body})
    |> Notification.put_badge(1)
    |> put_tab("dates")
  end
end
