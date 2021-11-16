defmodule T.PushNotifications.APNS do
  @moduledoc false

  alias T.Accounts.{PushKitDevice, APNSDevice}
  import T.Gettext
  require Logger

  @adapter Application.compile_env!(:t, [__MODULE__, :adapter])

  @spec push(APNS.notification()) :: APNS.response()
  def push(%{device_id: device_id} = notification) do
    with {:error, reason} = error when reason in [:bad_device_token, :unregistered] <-
           @adapter.push(notification) do
      Logger.warn("received error=#{reason} for #{device_id}")
      error
    end
  end

  @spec default_topic :: String.t()
  def default_topic do
    Application.fetch_env!(:t, __MODULE__)
    |> Keyword.fetch!(:default_topic)
  end

  @spec apns_env(%PushKitDevice{} | %APNSDevice{} | String.t() | nil) :: APNS.env()
  def apns_env(%PushKitDevice{env: env}), do: apns_env(env)
  def apns_env(%APNSDevice{env: env}), do: apns_env(env)
  def apns_env("prod"), do: :prod
  def apns_env("sandbox"), do: :dev
  def apns_env(nil), do: :dev

  # pushkit

  @spec pushkit_call([%PushKitDevice{}], map) :: [APNS.response()]
  def pushkit_call(devices, payload) when is_list(devices) do
    Enum.map(devices, fn device ->
      device
      |> build_call_notification(payload)
      |> push()
    end)
  end

  @spec build_call_notification(%PushKitDevice{}, map) :: APNS.notification()
  defp build_call_notification(device, payload) do
    %PushKitDevice{device_id: device_id, topic: topic} = device
    topic = topic || default_topic()
    APNS.build_notification(device_id, topic, payload, apns_env(device), _type = "voip")
  end

  # alerts

  @spec base_alert_payload(String.t(), map, map) :: map
  defp base_alert_payload(type, alert, extra) do
    Map.merge(extra, %{
      "type" => type,
      "aps" => %{"alert" => alert, "badge" => 1}
    })
  end

  @spec base_alert_payload(String.t(), map) :: map
  defp base_alert_payload(type, alert) do
    %{
      "type" => type,
      "aps" => %{"alert" => alert, "badge" => 1}
    }
  end

  @spec build_alert_payload(String.t(), map) :: map
  def build_alert_payload(template, data)

  def build_alert_payload("match" = type, _data) do
    alert = %{
      "title" => dgettext("apns", "Это новый мэтч!"),
      "body" => dgettext("apns", "Скорее заходи!")
    }

    base_alert_payload(type, alert)
  end

  def build_alert_payload("match_about_to_expire" = type, _data) do
    alert = %{
      "title" => dgettext("apns", "Your match is about to expire 😢"),
      "body" => dgettext("apns", "Invite your match to a date if you want to keep it alive ✨")
    }

    base_alert_payload(type, alert)
  end

  def build_alert_payload("invite" = type, data) do
    %{"user_id" => user_id, "name" => name} = data
    alert = %{"title" => dgettext("apns", "%{name} invited you to connect", name: name)}
    base_alert_payload(type, alert, %{"user_id" => user_id})
  end

  def build_alert_payload("timeslot_offer" = type, data) do
    alert = %{
      "title" => dgettext("apns", "Тебя пригласили на свидание!"),
      "body" => dgettext("apns", "Заходи, чтобы ответить на приглашение 👀")
    }

    base_alert_payload(type, alert, data)
  end

  def build_alert_payload("timeslot_accepted" = type, data) do
    alert = %{
      "title" => dgettext("apns", "Твое приглашение на дэйт принято"),
      "body" => dgettext("apns", "Добавь аудио-дэйт в календарь, чтобы не пропустить 🙌")
    }

    base_alert_payload(type, alert, data)
  end

  def build_alert_payload("timeslot_accepted_now" = type, data) do
    alert = %{
      "title" => dgettext("apns", "Твое приглашение на дэйт принято"),
      "body" => dgettext("apns", "Заходи и звони сейчас 👉")
    }

    base_alert_payload(type, alert, data)
  end

  def build_alert_payload("timeslot_cancelled" = type, data) do
    alert = %{
      "title" => dgettext("apns", "Твой дэйт отменён"),
      "body" => dgettext("apns", "Попробуй предложить другое время 👉")
    }

    base_alert_payload(type, alert, data)
  end

  def build_alert_payload("timeslot_reminder" = type, data) do
    alert = %{
      "title" => dgettext("apns", "Аудио-дэйт совсем скоро"),
      "body" => dgettext("apns", "Приготовься, у тебя 15 минут 👋")
    }

    base_alert_payload(type, alert, data)
  end

  def build_alert_payload("timeslot_started" = type, data) do
    alert = %{
      "title" => dgettext("apns", "Аудио-дэйт начинается"),
      "body" => dgettext("apns", "Скорее заходи и звони 🖤")
    }

    base_alert_payload(type, alert, data)
  end

  def build_alert_payload("complete_onboarding" = type, _data) do
    alert = %{
      "title" => dgettext("apns", "Hey, create your own cool profile ✨"),
      "body" => dgettext("apns", "Meet interesting people ✌️")
    }

    base_alert_payload(type, alert)
  end
end
