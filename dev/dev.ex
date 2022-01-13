defmodule Dev do
  def force_app_upgrade() do
    alert1_ru = %{
      "aps" => %{
        "alert" => %{
          "title" => "Ура, обновление! 🔥",
          "body" => "Новый режим — голосовая почта 🎤"
        }
      }
    }

    alert1_en = %{
      "aps" => %{
        "alert" => %{
          "title" => "Hurray, this is an update! 🔥",
          "body" => "Meet new mode: voicemail 🎤"
        }
      }
    }

    apns = T.Accounts.APNSDevice |> T.Repo.all()

    devices =
      Enum.map(apns, fn %{device_id: id} = device -> %{device | device_id: Base.encode16(id)} end)

    for device <- devices do
      %T.Accounts.APNSDevice{device_id: device_id, locale: locale, topic: topic, env: env} =
        device

      env =
        case env do
          "prod" -> :prod
          "sandbox" -> :dev
          nil -> :dev
        end

      case locale do
        "ru" ->
          APNS.build_notification(device_id, topic, alert1_ru, env) |> APNS.push(T.Finch)

        "en" ->
          APNS.build_notification(device_id, topic, alert1_en, env) |> APNS.push(T.Finch)

        _ ->
          APNS.build_notification(device_id, topic, alert1_ru, env) |> APNS.push(T.Finch)
      end
    end
  end
end
