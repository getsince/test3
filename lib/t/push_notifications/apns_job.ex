defmodule T.PushNotifications.APNSJob do
  @moduledoc false

  use Oban.Worker, queue: :apns, max_attempts: 5
  alias T.PushNotifications.APNS
  alias Pigeon.APNS.Notification

  @impl true
  def perform(%Oban.Job{args: args}) do
    %{"template" => template, "device_id" => device_id, "data" => data} = args
    n = build_notification(template, device_id, data)

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

  # (взаимным чувством
  # "#{name} тебя лойснула. Ты её тоже."
  defp build_notification("match", device_id, _data) do
    # %{"mate" => %{"name" => name, "gender" => gender}} = data

    # {title, body} =
    #   case gender do
    #     "F" ->

    #   end

    title = "Твоя симпатия взаимна 🎉"
    body = "Скорее заходи!"

    APNS.base_notification(device_id, "match")
    |> Notification.put_alert(%{"title" => title, "body" => body})
    |> Notification.put_badge(1)
    |> APNS.put_tab("matches")
  end

  # defp build_notification("yo", device_id, data) do
  #   %{"sender_name" => sender_name} = data

  #   title = "#{sender_name || "noname"} зовёт тебя пообщаться!"
  #   body = "Не упусти момент 😼"

  #   base_notification(device_id, "match")
  #   |> Notification.put_alert(%{"title" => title, "body" => body})
  #   |> Notification.put_badge(1)
  #   |> put_tab("matches")
  # end

  # defp build_notification("pending_match_activated", device_id, _data) do
  #   title = "Твоя симпатия взаимна!"
  #   body = "Скорее заходи! 🎉"

  #   base_notification(device_id)
  #   |> Notification.put_alert(%{"title" => title, "body" => body})
  #   |> Notification.put_badge(1)
  # end

  defp build_notification("message", device_id, _data) do
    # %{"mate" => %{"name" => name, "gender" => gender}} = data

    # {title, body} =
    #   case gender do
    #     "F" ->

    #   end

    title = "Тебе отправили сообщение ;)"
    body = "Не веришь? Проверь"

    APNS.base_notification(device_id, "message")
    |> Notification.put_alert(%{"title" => title, "body" => body})
    |> Notification.put_badge(1)
    |> APNS.put_tab("matches")
  end

  defp build_notification("support", device_id, _data) do
    title = "Пссс..."
    body = "Сообщение от поддержки 🌚"

    APNS.base_notification(device_id, "support")
    |> Notification.put_alert(%{"title" => title, "body" => body})
    |> Notification.put_badge(1)
    |> APNS.put_tab("support")
  end

  defp build_notification("timeslot_offer", device_id, _data) do
    title = "Тили-тили тесто"
    body = "Тебя на свиданку пригласили"

    APNS.base_notification(device_id, "timeslot_offer")
    |> Notification.put_alert(%{"title" => title, "body" => body})
    |> Notification.put_badge(1)
    |> APNS.put_tab("dates")
  end

  defp build_notification("timeslot_accepted", device_id, _data) do
    title = "Тили-тили тесто"
    body = "У кого-то свиданочка намечается"

    APNS.base_notification(device_id, "timeslot_accepted")
    |> Notification.put_alert(%{"title" => title, "body" => body})
    |> Notification.put_badge(1)
    |> APNS.put_tab("dates")
  end

  defp build_notification("timeslot_cancelled", device_id, data) do
    title = "Дейт отменён"
    body = "Тебя больше не хотят видеть"

    APNS.base_notification(device_id, "timeslot_cancelled")
    |> Notification.put_alert(%{"title" => title, "body" => body})
    |> Notification.put_custom(data)
    |> Notification.put_badge(1)
    |> APNS.put_tab("dates")
  end

  defp build_notification("timeslot_reminder", device_id, _data) do
    title = "Скоро свиданочка"
    body = "Приготовься, у тебя 15 минут"

    APNS.base_notification(device_id, "timeslot_reminder")
    |> Notification.put_alert(%{"title" => title, "body" => body})
    |> Notification.put_badge(1)
    |> APNS.put_tab("dates")
  end

  defp build_notification("timeslot_started", device_id, _data) do
    title = "Свидангу начинается"
    body = "Скорее заходи!"

    APNS.base_notification(device_id, "timeslot_started")
    |> Notification.put_alert(%{"title" => title, "body" => body})
    |> Notification.put_badge(1)
    |> APNS.put_tab("dates")
  end
end
