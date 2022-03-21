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

  alias T.{Repo, Matches, PushNotifications.DispatchJob}
  import Ecto.Query

  def backfill_match_about_to_expire do
    now = DateTime.truncate(DateTime.utc_now(), :second)
    match_ttl = Matches.match_ttl()
    two_hours = 2 * 3600
    not_yet_notified = DateTime.add(now, -match_ttl + two_hours)

    matches =
      "matches"
      |> where([m], m.inserted_at > ^not_yet_notified)
      |> select([m], {m.id, m.inserted_at})
      |> Repo.all()

    jobs =
      Enum.map(matches, fn {id, inserted_at} ->
        before_expire = DateTime.add(inserted_at, match_ttl - two_hours)

        %{"type" => "match_about_to_expire", "match_id" => id}
        |> DispatchJob.new(scheduled_at: before_expire)
      end)

    Oban.insert_all(jobs)
  end

  def backfill_onboarding_nags do
    now = DateTime.truncate(DateTime.utc_now(), :second)
    not_yet_notified = DateTime.add(now, -24 * 3600)

    users =
      "users"
      |> where([u], u.inserted_at > ^not_yet_notified)
      |> select([u], {u.id, u.inserted_at})
      |> Repo.all()

    jobs =
      Enum.map(users, fn {id, inserted_at} ->
        DispatchJob.new(
          %{"type" => "complete_onboarding", "user_id" => id},
          scheduled_at: _in_24h = DateTime.add(inserted_at, 24 * 3600)
        )
      end)

    Oban.insert_all(jobs)
  end
end
