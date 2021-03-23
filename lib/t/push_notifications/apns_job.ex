defmodule T.PushNotifications.APNSJob do
  @moduledoc false

  use Oban.Worker, queue: :apns, max_attempts: 5
  alias Pigeon.APNS.Notification
  alias Pigeon.APNS

  @impl true
  def perform(%Oban.Job{args: args}) do
    %{"template" => template, "device_id" => device_id, "data" => data} = args
    n = build_notification(template, device_id, data)
    push_all_envs(n)
  end

  def push_all_envs(n) do
    Application.fetch_env!(:pigeon, :apns)
    |> Enum.map(fn {worker, _} -> APNS.push(n, to: worker) end)
    |> case do
      [n] -> n
      [%Notification{response: :success} = n, _n] -> n
      [_n, %Notification{response: :success} = n] -> n
      [_, _] = fails -> fails
    end
    |> List.wrap()
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

  defp topic do
    Application.fetch_env!(:pigeon, :apns)[:apns_default].topic
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

    base_notification(device_id, "match")
    |> Notification.put_alert(%{"title" => title, "body" => body})
    |> Notification.put_badge(1)
  end

  defp build_notification("yo", device_id, data) do
    %{"sender_name" => sender_name} = data

    title = "#{sender_name || "noname"} зовёт тебя пообщаться!"
    body = "Не упусти момент 😼"

    base_notification(device_id, "match")
    |> Notification.put_alert(%{"title" => title, "body" => body})
    |> Notification.put_badge(1)
  end

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

    base_notification(device_id, "message")
    |> Notification.put_alert(%{"title" => title, "body" => body})
    |> Notification.put_badge(1)
  end

  defp build_notification("support", device_id, _data) do
    title = "Пссс..."
    body = "Сообщение от поддержки 🌚"

    base_notification(device_id, "support")
    |> Notification.put_alert(%{"title" => title, "body" => body})
    |> Notification.put_badge(1)
  end

  defp build_notification("timeslot_offer", device_id, _data) do
    title = "Тили-тили тесто"
    body = "Тебя на свиданку пригласили"

    base_notification(device_id, "timeslot_offer")
    |> Notification.put_alert(%{"title" => title, "body" => body})
    |> Notification.put_badge(1)
  end

  defp build_notification("timeslot_accepted", device_id, _data) do
    title = "Тили-тили тесто"
    body = "У кого-то свиданочка намечается"

    base_notification(device_id, "timeslot_accepted")
    |> Notification.put_alert(%{"title" => title, "body" => body})
    |> Notification.put_badge(1)
  end

  defp build_notification("timeslot_reminder", device_id, _data) do
    title = "Скоро свиданочка"
    body = "Приготовься, у тебя 15 минут"

    base_notification(device_id, "timeslot_accepted")
    |> Notification.put_alert(%{"title" => title, "body" => body})
    |> Notification.put_badge(1)
  end

  defp base_notification(device_id, collapse_id) do
    %Notification{
      device_token: device_id,
      topic: topic(),
      # TODO thread id
      collapse_id: collapse_id
    }
  end
end
