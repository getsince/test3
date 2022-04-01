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

  def onboard_users_with_random_locations(count) do
    for i <- 0..count, i > 0 do
      lat = (:rand.uniform() - 0.5) * 180.0
      lon = (:rand.uniform() - 0.5) * 360.0

      opts = [lat: lat, lon: lon]

      {:ok, user} =
        T.Accounts.register_user_with_apple_id(%{"apple_id" => apple_id()}, DateTime.utc_now())

      {:ok, _profile} = T.Accounts.onboard_profile(user.id, onboarding_attrs(opts))
    end
  end

  def apple_id do
    # 000701.5bccb2a610e04475a96dbe39e47cda09.1630
    # 001848.6244ee9f0798419db44fbedac8861ce1.1236
    # 000822.7fc739b031e542e19fd7b877cdd23122.2012
    rand = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
    "000701." <> rand <> ".1630"
  end

  def onboarding_attrs(opts \\ []) do
    gender = opts[:gender] || "M"

    story =
      if Keyword.has_key?(opts, :story) do
        opts[:story]
      else
        profile_story()
      end

    %{
      story: story,
      latitude: opts[:lat],
      longitude: opts[:lon],
      birthdate: opts[:birthdate] || "1998-10-28",
      gender: gender,
      name: opts[:name] || "that",
      gender_preference: opts[:accept_genders] || ["F"],
      distance: opts[:distance],
      max_age: opts[:max_age],
      min_age: opts[:min_age]
    }
  end

  def profile_story do
    [
      %{
        "background" => %{
          "s3_key" => "photo.jpg"
        },
        "labels" => [
          %{
            "type" => "text",
            "value" => "just some text",
            "dimensions" => [400, 800],
            "position" => [100, 100],
            "rotation" => 21,
            "zoom" => 1.2
          },
          %{
            "answer" => "durov",
            "question" => "telegram",
            "position" => [150, 150]
          }
        ]
      }
    ]
  end
end
