defmodule T.PushNotifications.APNS do
  @moduledoc false

  alias Pigeon.APNS.Notification
  alias T.PushNotifications.Helpers
  alias T.Accounts.{PushKitDevice, APNSDevice}
  import T.Gettext

  @adapter Application.compile_env!(:t, [__MODULE__, :adapter])

  @type apns_env :: :prod | :dev

  @spec push(%Notification{}, apns_env) :: %Notification{}
  @spec push([%Notification{}], apns_env) :: [%Notification{}]
  defp push([] = empty, _env), do: empty

  defp push(notifications, env) when env in [:dev, :prod] do
    @adapter.push(notifications, env)
  end

  def topic do
    :t
    |> Application.fetch_env!(__MODULE__)
    |> Keyword.fetch!(:topic)
  end

  @spec apns_env(%PushKitDevice{} | %APNSDevice{}) :: apns_env
  defp apns_env(%PushKitDevice{env: "prod"}), do: :prod
  defp apns_env(%PushKitDevice{env: "sandbox"}), do: :dev
  defp apns_env(%PushKitDevice{env: nil}), do: :dev

  defp apns_env(%APNSDevice{env: "prod"}), do: :prod
  defp apns_env(%APNSDevice{env: "sandbox"}), do: :dev
  defp apns_env(%APNSDevice{env: nil}), do: :dev

  @spec apns_topic(%PushKitDevice{} | %APNSDevice{}) :: String.t()
  defp apns_topic(%PushKitDevice{topic: topic}) when is_binary(topic), do: topic
  defp apns_topic(%PushKitDevice{topic: nil}), do: topic()

  defp apns_topic(%APNSDevice{topic: topic}) when is_binary(topic), do: topic
  defp apns_topic(%APNSDevice{topic: nil}), do: topic()

  # pushkit

  @spec pushkit_call([%PushKitDevice{}], map) :: [%Notification{}]
  def pushkit_call(devices, payload) when is_list(devices) do
    grouped_devices = Enum.group_by(devices, fn device -> apns_env(device) end)

    prod_n =
      (grouped_devices[:prod] || [])
      |> Enum.map(&build_call_notification(&1, payload))
      |> push(:prod)

    dev_n =
      (grouped_devices[:dev] || [])
      |> Enum.map(&build_call_notification(&1, payload))
      |> push(:dev)

    prod_n ++ dev_n
  end

  @spec build_call_notification(%PushKitDevice{}, map) :: %Notification{}
  defp build_call_notification(%PushKitDevice{device_id: device_id} = device, payload) do
    %Notification{
      device_token: device_id,
      topic: apns_topic(device) <> ".voip",
      push_type: "voip",
      expiration: 0,
      payload: payload
    }
  end

  # alerts

  @spec push_alert(String.t(), %APNSDevice{}, map) :: %Notification{}
  def push_alert(template, device, data) do
    notification_locale(device)
    |> Gettext.with_locale(fn -> build_notification(template, device, data) end)
    |> push(apns_env(device))
  end

  @spec notification_locale(%APNSDevice{}) :: String.t()
  defp notification_locale(%APNSDevice{locale: locale}) when is_binary(locale), do: locale
  defp notification_locale(%APNSDevice{locale: nil}), do: "en"

  @spec base_notification(%APNSDevice{}, String.t(), map) :: %Notification{}
  defp base_notification(%APNSDevice{device_id: device_id} = device, type, data) do
    %Notification{
      device_token: device_id,
      topic: apns_topic(device),
      # TODO repalce with thread id, possibly remove collapse id
      collapse_id: type
    }
    # TODO is this needed?
    |> Notification.put_mutable_content()
    |> Notification.put_custom(%{"type" => type})
    |> Notification.put_custom(data)
  end

  @spec build_notification(String.t(), %APNSDevice{}, map) :: %Notification{}
  defp build_notification(template, device, date)

  defp build_notification("match", device, data) do
    title = dgettext("apns", "Это новый мэтч!")
    body = dgettext("apns", "Скорее заходи!")

    base_notification(device, "match", data)
    |> Notification.put_alert(%{"title" => title, "body" => body})
    |> Notification.put_badge(1)
  end

  defp build_notification("invite", device, data) do
    %{"user_id" => user_id, "name" => name} = data

    # TODO if current locale is ru, don't translitirate
    name_en = Helpers.translitirate_to_en(name)
    title = dgettext("apns", "%{name} invited you for a call", name: name_en)

    base_notification(device, "invite", %{"user_id" => user_id})
    |> Notification.put_alert(%{"title" => title})
    |> Notification.put_badge(1)
  end

  defp build_notification("timeslot_offer", device, data) do
    title = dgettext("apns", "Тебя пригласили на свидание!")
    body = dgettext("apns", "Заходи, чтобы ответить на приглашение 👀")

    base_notification(device, "timeslot_offer", data)
    |> Notification.put_alert(%{"title" => title, "body" => body})
    |> Notification.put_badge(1)
  end

  defp build_notification("timeslot_accepted", device, data) do
    title = dgettext("apns", "Твое приглашение на дэйт принято")
    body = dgettext("apns", "Добавь аудио-дэйт в календарь, чтобы не пропустить 🙌")

    base_notification(device, "timeslot_accepted", data)
    |> Notification.put_alert(%{"title" => title, "body" => body})
    |> Notification.put_badge(1)
  end

  defp build_notification("timeslot_cancelled", device, data) do
    title = dgettext("apns", "Твой дэйт отменён")
    body = dgettext("apns", "Попробуй предложить другое время 👉")

    base_notification(device, "timeslot_cancelled", data)
    |> Notification.put_alert(%{"title" => title, "body" => body})
    |> Notification.put_custom(data)
    |> Notification.put_badge(1)
  end

  defp build_notification("timeslot_reminder", device, data) do
    title = dgettext("apns", "Аудио-дэйт совсем скоро")
    body = dgettext("apns", "Приготовься, у тебя 15 минут 👋")

    base_notification(device, "timeslot_reminder", data)
    |> Notification.put_alert(%{"title" => title, "body" => body})
    |> Notification.put_badge(1)
  end

  defp build_notification("timeslot_started", device, data) do
    title = dgettext("apns", "Аудио-дэйт начинается")
    body = dgettext("apns", "Скорее заходи и звони 🖤")

    base_notification(device, "timeslot_started", data)
    |> Notification.put_alert(%{"title" => title, "body" => body})
    |> Notification.put_badge(1)
  end
end
