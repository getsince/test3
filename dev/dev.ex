defmodule Dev do
  def force_app_upgrade() do
    alert1_ru = %{
      "aps" => %{
        "alert" => %{
          "title" => "Обнови приложение 👋",
          "body" => "Встречай Since LIVE — новый формат вечеринки 🎉"
        }
      }
    }

    alert1_en = %{
      "aps" => %{
        "alert" => %{
          "title" => "Update the app 👋",
          "body" => "Meet Since LIVE, a new party format 🎉"
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

tokens = [
  "zH8kYe3GzPpO1kt6jLAYcEFOTFeuNEyNkIuvg3yVioQ=",
  "V7OnJqdX4grwUdpHr8ZqxVrFRmwU09GctvOyDTCxrzU=",
  "nJu1lSrLH6kXLsJN3LFblnYZ8A2oRAp66gzkSCajA+Q=",
  "W7gK/82KvaoR0x4qHmMdVReo3ELKLMUFkzpJGGsSEOU=",
  "23RFpbhp6Dr4jfRTi4hcS7ESTtesA4xO67e6+2f1lK8=",
  "rc430QRoOfJ6u7NXic6tAYo2yjRl6SrcF3gz9OYD8DY=",
  "9pQUl+/da5PBXZAndjliircdh35yVgpkahzO2vTCkZI=",
  "TzMWHtmyWKzG5HrTeVfcviOXd3k7trV95oIKN7k4kuc="
]

Enum.each(tokens, fn token ->
  token = token |> Base.decode64!() |> T.Accounts.UserToken.encoded_token()
  TWeb.Endpoint.broadcast!("disconnect", "user_socket:" <> token, %{})
end)
