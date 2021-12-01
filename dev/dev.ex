defmodule Dev do
  def force_app_upgrade() do
    alert1_ru = %{
      "aps" => %{
        "alert" => %{
          "title" => "Обнови приложение в App Store ✨",
          "body" => "Текущая версия больше не поддерживается 🙃"
        }
      }
    }

    alert2_ru = %{
      "aps" => %{
        "alert" => %{
          "title" => "В обновлении много важного 👉",
          "body" => "Попробуй обмен контактами прямо из ленты 👀"
        }
      }
    }

    alert1_en = %{
      "aps" => %{
        "alert" => %{
          "title" => "Update the app in the App Store ✨",
          "body" => "The current version is no longer supported 🙃"
        }
      }
    }

    alert2_en = %{
      "aps" => %{
        "alert" => %{
          "title" => "Meet important things in the update 👉",
          "body" => "Try sharing contacts straight from your feed 👀"
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
          APNS.build_notification(device_id, topic, alert2_ru, env) |> APNS.push(T.Finch)

        "en" ->
          APNS.build_notification(device_id, topic, alert1_en, env) |> APNS.push(T.Finch)
          APNS.build_notification(device_id, topic, alert2_en, env) |> APNS.push(T.Finch)

        _ ->
          APNS.build_notification(device_id, topic, alert1_ru, env) |> APNS.push(T.Finch)
          APNS.build_notification(device_id, topic, alert2_ru, env) |> APNS.push(T.Finch)
      end
    end
  end
end
