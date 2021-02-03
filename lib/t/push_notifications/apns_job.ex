defmodule T.PushNotifications.APNSJob do
  @moduledoc false

  use Oban.Worker, queue: :apns
  alias Pigeon.APNS.Notification
  alias Pigeon.APNS

  @impl true
  def perform(%Oban.Job{args: args}) do
    %{"template" => template, "device_id" => device_id, "data" => data} = args
    n = build_notification(template, device_id, data)

    case APNS.push(n) do
      %Notification{response: :bad_device_token} ->
        # TODO remove_device(device_id)
        :discard

      %Notification{response: :success} ->
        :ok
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

    title = "Твоя симпатия взаимна!"
    body = "Скорее заходи! 🎉"

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

  defp base_notification(device_id, collapse_id) do
    %Notification{
      device_token: device_id,
      topic: topic(),
      collapse_id: collapse_id
    }
  end
end
