defmodule T.PushNotifications.APNS do
  @moduledoc false

  alias T.Accounts.APNSDevice
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

  @spec apns_env(%APNSDevice{} | String.t() | nil) :: APNS.env()
  def apns_env(%APNSDevice{env: env}), do: apns_env(env)
  def apns_env("prod"), do: :prod
  def apns_env("sandbox"), do: :dev
  def apns_env(nil), do: :dev

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

  def build_alert_payload("match_no_contact" = type, _data) do
    alert = %{
      "title" => dgettext("apns", "Это новый мэтч!"),
      "body" => dgettext("apns", "Добавь контакт в свой профиль, чтобы с тобой могли связаться")
    }

    base_alert_payload(type, alert)
  end

  def build_alert_payload("match_about_to_expire" = type, data) do
    %{"name" => name} = data
    # TODO proper in the next release
    gender = data["gender"]

    alert = %{
      "title" => dgettext("apns", "Match with %{name} is about to expire", name: name),
      "body" => dgettext("apns", "Contact %{pronoun} ✨", pronoun: pronoun(gender))
    }

    base_alert_payload(type, alert)
  end

  def build_alert_payload("invite" = type, data) do
    %{"user_id" => user_id, "name" => name} = data
    alert = %{"title" => dgettext("apns", "%{name} invited you to connect", name: name)}
    base_alert_payload(type, alert, %{"user_id" => user_id})
  end

  def build_alert_payload("timeslot_offer" = type, data) do
    %{"name" => name, "gender" => gender} = data

    gender_a = if gender == "F", do: "a", else: ""

    alert = %{
      "title" =>
        dgettext("apns", "%{name} пригласил%{gender_a} тебя на дэйт!",
          name: name,
          gender_a: gender_a
        ),
      "body" => dgettext("apns", "Заходи, чтобы ответить на приглашение 👀")
    }

    base_alert_payload(type, alert, data)
  end

  def build_alert_payload("timeslot_accepted" = type, data) do
    %{"name" => name} = data

    alert = %{
      "title" => dgettext("apns", "Приглашение на дэйт c %{name} принято", name: name),
      "body" => dgettext("apns", "Аудио-дэйт уже в твоём календаре, не пропусти 👀")
    }

    base_alert_payload(type, alert, data)
  end

  def build_alert_payload("timeslot_accepted_now" = type, data) do
    %{"name" => name} = data

    alert = %{
      "title" => dgettext("apns", "Приглашение на дэйт c %{name} принято", name: name),
      "body" => dgettext("apns", "Заходи и звони сейчас 👉")
    }

    base_alert_payload(type, alert, data)
  end

  def build_alert_payload("timeslot_cancelled" = type, data) do
    %{"name" => name} = data

    alert = %{
      "title" => dgettext("apns", "Твой дэйт с %{name} отменён", name: name),
      "body" => dgettext("apns", "Попробуй предложить другое время 👉")
    }

    base_alert_payload(type, alert, data)
  end

  def build_alert_payload("timeslot_reminder" = type, data) do
    %{"name" => name} = data

    alert = %{
      "title" => dgettext("apns", "Аудио-дэйт с %{name} совсем скоро", name: name),
      "body" => dgettext("apns", "Приготовься, у тебя 15 минут 👋")
    }

    base_alert_payload(type, alert, data)
  end

  def build_alert_payload("timeslot_started" = type, data) do
    %{"name" => name} = data

    alert = %{
      "title" => dgettext("apns", "Аудио-дэйт с %{name} начинается", name: name),
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

  def build_alert_payload("contact_offer" = type, data) do
    %{"name" => name, "gender" => gender} = data

    gender_a = if gender == "F", do: "a", else: ""

    alert = %{
      "title" =>
        dgettext("apns", "%{name} прислал%{gender_a} тебe контакт!",
          name: name,
          gender_a: gender_a
        ),
      "body" => dgettext("apns", "Заходи, чтобы просмотреть и написать ✨")
    }

    base_alert_payload(type, alert, data)
  end

  def build_alert_payload("upgrade_app" = type, _data) do
    alert = %{
      "title" => dgettext("apns", "Update the app in the App Store ✨"),
      "body" => dgettext("apns", "The current version is no longer supported 🙃")
    }

    base_alert_payload(type, alert)
  end

  defp pronoun("F"), do: dgettext("apns", "her")
  defp pronoun("M"), do: dgettext("apns", "him")
  defp pronoun(_), do: dgettext("apns", "them")

  # backround notifications

  def background_notification_payload(type, data) do
    Map.merge(data, %{"type" => type, "aps" => %{"content-available" => "1"}})
  end
end
