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

  def build_alert_payload(type, %{"name_from" => name_from, "gender_from" => gender_from} = data)
      when type in ["message", "drawing", "video", "audio", "spotify", "contact"] do
    verb_ending_ru =
      case gender_from do
        "F" -> "а"
        "N" -> "и"
        "M" -> ""
      end

    body =
      case type do
        "message" ->
          dgettext("apns", "sent%{verb_ending_ru} a message", verb_ending_ru: verb_ending_ru)

        "drawing" ->
          dgettext("apns", "sent%{verb_ending_ru} a drawing", verb_ending_ru: verb_ending_ru)

        "video" ->
          dgettext("apns", "sent%{verb_ending_ru} a video message", verb_ending_ru: verb_ending_ru)

        "audio" ->
          dgettext("apns", "sent%{verb_ending_ru} a voice message", verb_ending_ru: verb_ending_ru)

        "spotify" ->
          dgettext("apns", "sent%{verb_ending_ru} a music track", verb_ending_ru: verb_ending_ru)

        "contact" ->
          dgettext("apns", "sent%{verb_ending_ru} a contact", verb_ending_ru: verb_ending_ru)
      end

    alert = %{"title" => name_from, "body" => body}
    base_alert_payload(type, alert, data)
  end

  def build_alert_payload("invite" = type, data) do
    %{"user_id" => user_id, "name" => name} = data
    alert = %{"title" => dgettext("apns", "%{name} invited you to connect", name: name)}
    base_alert_payload(type, alert, %{"user_id" => user_id})
  end

  def build_alert_payload("complete_onboarding" = type, _data) do
    alert = %{
      "title" => dgettext("apns", "Hey, create your own cool profile ✨"),
      "body" => dgettext("apns", "Meet interesting people ✌️")
    }

    base_alert_payload(type, alert)
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
end
