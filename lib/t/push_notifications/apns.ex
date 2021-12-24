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

  def build_alert_payload("match_about_to_expire" = type, data) do
    %{"name" => name} = data

    alert = %{
      "title" => dgettext("apns", "Match with %{name} is about to expire", name: name),
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

  def build_alert_payload("live_invite" = type, data) do
    %{"user_id" => user_id, "name" => name} = data

    alert = %{
      "title" => dgettext("apns", "%{name} invites you to talk 👉", name: name),
      "body" => dgettext("apns", "Call now, this is Since Live 🎉")
    }

    base_alert_payload(type, alert, %{"user_id" => user_id})
  end

  def build_alert_payload("match_went_live" = type, data) do
    %{"user_id" => user_id, "name" => name, "gender" => gender} = data

    gender_a = if gender == "F", do: "a", else: ""

    alert = %{
      "title" => dgettext("apns", "Мэтч %{name} онлайн 👋", name: name),
      "body" =>
        dgettext("apns", "...и готов%{gender_a} общаться! Заходи и звони сейчас 👉",
          gender_a: gender_a
        )
    }

    base_alert_payload(type, alert, %{"user_id" => user_id})
  end

  def build_alert_payload("live_mode_today" = type, %{"time" => time}) do
    alert = %{
      "title" => dgettext("apns", "Since LIVE today 🥳"),
      "body" => dgettext("apns", "Come to the party at %{time}, it will be 🔥", time: time)
    }

    base_alert_payload(type, alert, %{})
  end

  def build_alert_payload("live_mode_soon" = type, _data) do
    alert = %{
      "title" => dgettext("apns", "Since LIVE starts soon 🔥"),
      "body" => dgettext("apns", "Come chat with new people 🥳")
    }

    base_alert_payload(type, alert, %{})
  end

  def build_alert_payload("live_mode_started" = type, _data) do
    alert = %{
      "title" => dgettext("apns", "Since Live starts 🥳"),
      "body" => dgettext("apns", "Come to the party and chat 🎉")
    }

    base_alert_payload(type, alert, %{})
  end

  def build_alert_payload("live_mode_ended" = type, %{"next" => next}) do
    alert = %{
      "title" => dgettext("apns", "Since Live ended ✌️"),
      "body" =>
        dgettext("apns", "Wait for the party %{on_weekday} 👀", on_weekday: on_weekday(next))
    }

    base_alert_payload(type, alert, %{})
  end

  # newbies alerts

  # maybe have some play on `orientation` (as in uni)
  # 3. familiarization with something: many judges give instructions to assist jury orientation.
  #    • (also orientation course) _mainly North American_ a course giving information to
  #                                newcomers to a university or other institution.

  def build_alert_payload("newbie_live_mode_today" = type, %{"time" => time}) do
    alert = %{
      # like "Since Live orientation today"
      "title" => dgettext("apns", "Since LIVE today 🥳"),
      "body" => dgettext("apns", "Come to the party at %{time}, it will be 🔥", time: time)
    }

    base_alert_payload(type, alert, %{})
  end

  def build_alert_payload("newbie_live_mode_soon" = type, _data) do
    alert = %{
      "title" => dgettext("apns", "Since LIVE starts soon 🔥"),
      "body" => dgettext("apns", "Come chat with new people 🥳")
    }

    base_alert_payload(type, alert, %{})
  end

  def build_alert_payload("newbie_live_mode_started" = type, _data) do
    alert = %{
      "title" => dgettext("apns", "Since Live starts 🥳"),
      "body" => dgettext("apns", "Only you and other new users are invited 🎉")
    }

    base_alert_payload(type, alert, %{})
  end

  def build_alert_payload("newbie_live_mode_ended" = type, %{"next" => next}) do
    alert = %{
      "title" => dgettext("apns", "Since Live for newbies is over ✌️"),
      "body" =>
        dgettext("apns", "Wait for the real party %{on_weekday} 👀", on_weekday: on_weekday(next))
    }

    base_alert_payload(type, alert, %{})
  end

  # backround notifications

  def background_notification_payload(type, data) do
    Map.merge(data, %{"type" => type, "aps" => %{"content-available" => "1"}})
  end

  @spec on_weekday(String.t() | Date.t()) :: String.t()
  defp on_weekday(next) when is_binary(next) do
    next |> Date.from_iso8601!() |> on_weekday()
  end

  defp on_weekday(%Date{} = next) do
    case Date.day_of_week(next) do
      1 -> dgettext("apns", "on Monday")
      2 -> dgettext("apns", "on Tuesday")
      3 -> dgettext("apns", "on Wednesday")
      4 -> dgettext("apns", "on Thursday")
      5 -> dgettext("apns", "on Friday")
      6 -> dgettext("apns", "on Saturday")
      7 -> dgettext("apns", "on Sunday")
    end
  end
end
