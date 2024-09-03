defmodule Since.PushNotifications.APNS do
  @moduledoc false

  alias Since.Accounts.APNSDevice
  alias Since.Games
  import Since.Gettext
  require Logger

  @adapter Application.compile_env!(:since, [__MODULE__, :adapter])

  @spec push(APNS.notification()) :: APNS.response()
  def push(%{device_id: device_id} = notification) do
    with {:error, reason} = error when reason in [:bad_device_token, :unregistered] <-
           @adapter.push(notification) do
      Logger.warning("received error=#{reason} for #{device_id}")
      error
    end
  end

  @spec default_topic :: String.t()
  def default_topic do
    Application.fetch_env!(:since, __MODULE__)
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

  def build_alert_payload(type, %{"name_from" => name_from, "gender_from" => gender_from} = data)
      when type in [
             "invitation",
             "acceptance",
             "meeting_request",
             "meeting_approval",
             "meeting_decline",
             "text",
             "drawing",
             "video",
             "audio",
             "spotify",
             "contact",
             "photo"
           ] do
    verb_ending_ru =
      case gender_from do
        "F" -> "а"
        "N" -> "и"
        "M" -> ""
      end

    body =
      case type do
        "invitation" ->
          dgettext("apns", "invited you to connect")

        "acceptance" ->
          dgettext("apns", "accepted%{verb_ending_ru} your invitation",
            verb_ending_ru: verb_ending_ru
          )

        "meeting_request" ->
          dgettext("apns", "wants to join your meeting")

        "meeting_approval" ->
          dgettext("apns", "approved your request to join the meeting")

        "meeting_decline" ->
          dgettext("apns", "declined your request to join the meeting")

        "text" ->
          data["data"]["value"]

        "drawing" ->
          dgettext("apns", "sent%{verb_ending_ru} a drawing", verb_ending_ru: verb_ending_ru)

        "video" ->
          dgettext("apns", "sent%{verb_ending_ru} a video message",
            verb_ending_ru: verb_ending_ru
          )

        "audio" ->
          dgettext("apns", "sent%{verb_ending_ru} a voice message",
            verb_ending_ru: verb_ending_ru
          )

        "spotify" ->
          dgettext("apns", "sent%{verb_ending_ru} a music track", verb_ending_ru: verb_ending_ru)

        "contact" ->
          dgettext("apns", "sent%{verb_ending_ru} a contact", verb_ending_ru: verb_ending_ru)

        "photo" ->
          dgettext("apns", "sent%{verb_ending_ru} a photo", verb_ending_ru: verb_ending_ru)
      end

    alert = %{"title" => name_from, "body" => body}
    base_alert_payload(type, alert, data)
  end

  def build_alert_payload(
        "compliment_revealed" = type,
        %{
          "prompt" => prompt,
          "name_from" => name_from,
          "gender_from" => gender_from,
          "emoji" => emoji
        } = data
      ) do
    title = emoji <> " " <> dgettext("apns", "This is a match!")

    verb_ending_ru =
      case gender_from do
        "F" -> "а"
        "N" -> "и"
        "M" -> ""
      end

    body =
      if prompt == "like" do
        dgettext("apns", "%{name} liked%{verb_ending_ru} you back",
          name: name_from,
          verb_ending_ru: verb_ending_ru
        )
      else
        dgettext("apns", "%{name} chose%{verb_ending_ru} you in the game",
          name: name_from,
          verb_ending_ru: verb_ending_ru
        )
      end

    alert = %{"title" => title, "body" => body}
    base_alert_payload(type, alert, data)
  end

  def build_alert_payload(
        "compliment" = type,
        %{
          "prompt" => prompt,
          "emoji" => emoji,
          "premium" => premium,
          "from_user_name" => from_user_name,
          "from_user_gender" => from_user_gender
        } = data
      ) do
    title =
      if premium do
        emoji <>
          " " <> from_user_name <> " " <> Games.render(prompt <> "_push_" <> from_user_gender)
      else
        emoji <> " " <> dgettext("apns", "Someone ") <> Games.render(prompt <> "_push_M")
      end

    body =
      if premium do
        dgettext("apns", "Check %{pronoun_having} out!",
          pronoun_having: pronoun_having(from_user_gender)
        )
      else
        dgettext("apns", "Play the game to find out!")
      end

    alert = %{"title" => title, "body" => body}
    base_alert_payload(type, alert, data)
  end

  # TODO remove
  def build_alert_payload("compliment" = type, %{"prompt" => prompt, "emoji" => emoji} = data) do
    title = emoji <> " " <> dgettext("apns", "Someone ") <> Games.render(prompt <> "_push_M")
    body = dgettext("apns", "Play the game to find out!")

    alert = %{"title" => title, "body" => body}
    base_alert_payload(type, alert, data)
  end

  # TODO remove
  def build_alert_payload(
        "private_page_available" = type,
        %{"name_of" => name_of, "gender_of" => gender_of} = data
      ) do
    verb_ending_ru =
      case gender_of do
        "F" -> "а"
        "N" -> "и"
        "M" -> ""
      end

    title =
      dgettext("apns", "%{name_of} replied%{verb_ending_ru} to you",
        name_of: name_of,
        verb_ending_ru: verb_ending_ru
      )

    body =
      dgettext("apns", "Now you can see %{pronoun_belonging_to} private pages",
        pronoun_belonging_to: pronoun_belonging_to(gender_of)
      )

    alert = %{"title" => title, "body" => body}
    base_alert_payload(type, alert, data)
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

  def build_alert_payload("compliment_limit_reset" = type, %{"prompt" => "like"}) do
    alert = %{"title" => dgettext("apns", "You can start matching up again ✨")}

    base_alert_payload(type, alert)
  end

  def build_alert_payload("compliment_limit_reset" = type, _data) do
    alert = %{"title" => dgettext("apns", "You can start playing the game again ✨")}

    base_alert_payload(type, alert)
  end

  defp pronoun_belonging_to("F"), do: dgettext("apns", "her BELONGING TO")
  defp pronoun_belonging_to("M"), do: dgettext("apns", "his BELONGING TO")
  defp pronoun_belonging_to(_), do: dgettext("apns", "their BELONGING TO")

  defp pronoun_having("F"), do: dgettext("apns", "her HAVING")
  defp pronoun_having("M"), do: dgettext("apns", "him HAVING")
  defp pronoun_having(_), do: dgettext("apns", "them HAVING")
end
