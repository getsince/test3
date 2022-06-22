defmodule T.PushNotifications.DispatchJob do
  # TODO unique per user id?
  # TODO remove all notifications when unmatched

  use Oban.Worker, queue: :apns
  import Ecto.Query
  alias T.{Repo, Matches, Accounts, PushNotifications}

  @impl true
  def perform(%Oban.Job{args: %{"type" => type} = args}) do
    handle_type(type, args)
  end

  defp handle_type("match", args) do
    %{"match_id" => match_id} = args

    if match = alive_match(match_id) do
      %Matches.Match{user_id_1: uid1, user_id_2: uid2} = match

      data = %{"match_id" => match_id}
      uid1 |> Accounts.list_apns_devices() |> schedule_apns("match", data)
      uid2 |> Accounts.list_apns_devices() |> schedule_apns("match", data)

      :ok
    else
      :discard
    end
  end

  defp handle_type("match_about_to_expire", args) do
    %{"match_id" => match_id} = args

    if match = alive_match(match_id) do
      unless Matches.has_undying_events?(match_id) do
        %Matches.Match{user_id_1: uid1, user_id_2: uid2} = match
        profile1 = profile_info(uid1)
        profile2 = profile_info(uid2)

        if profile1 && profile2 do
          {name1, gender1} = profile1
          {name2, gender2} = profile2
          data1 = %{"match_id" => match_id, "name" => name2, "gender" => gender2}
          data2 = %{"match_id" => match_id, "name" => name1, "gender" => gender1}

          case Matches.has_interaction?(match_id) do
            nil ->
              uid1
              |> Accounts.list_apns_devices()
              |> schedule_apns("match_about_to_expire", data1)

              uid2
              |> Accounts.list_apns_devices()
              |> schedule_apns("match_about_to_expire", data2)

            %Matches.Interaction{to_user_id: to_user_id} ->
              case to_user_id do
                ^uid1 ->
                  uid1
                  |> Accounts.list_apns_devices()
                  |> schedule_apns("match_about_to_expire_please_reply", data1)

                ^uid2 ->
                  uid2
                  |> Accounts.list_apns_devices()
                  |> schedule_apns("match_about_to_expire_please_reply", data2)
              end
          end
        end
      end
    end

    :ok
  end

  defp handle_type(type, %{"from_user_id" => from_user_id, "to_user_id" => to_user_id} = args)
       when type in ["message", "drawing", "video", "audio", "spotify", "contact", "photo"] do
    profile_from = profile_info(from_user_id)

    if profile_from do
      {name_from, gender_from} = profile_from
      data = args |> Map.merge(%{"name_from" => name_from, "gender_from" => gender_from})
      to_user_id |> Accounts.list_apns_devices() |> schedule_apns(type, data)
    end

    :ok
  end

  defp handle_type("invite" = type, args) do
    %{"by_user_id" => by_user_id, "user_id" => user_id} = args

    if profile = profile_info(by_user_id) do
      {name, _gender} = profile

      data = %{"user_id" => by_user_id, "name" => name}

      user_id |> Accounts.list_apns_devices() |> schedule_apns(type, data)
    end

    :ok
  end

  defp handle_type("complete_onboarding" = type, args) do
    %{"user_id" => user_id} = args

    unless has_story?(user_id) do
      user_id |> Accounts.list_apns_devices() |> schedule_apns(type, args)
    end

    :ok
  end

  defp handle_type("upgrade_app" = type, args) do
    %{"user_id" => user_id} = args

    user_id |> Accounts.list_apns_devices() |> schedule_apns(type, args)

    :ok
  end

  defp profile_info(user_id) do
    Accounts.Profile
    |> where(user_id: ^user_id)
    |> select([p], {p.name, p.gender})
    |> Repo.one()
  end

  defp alive_match(match_id) do
    Matches.Match
    |> where(id: ^match_id)
    |> Repo.one()
  end

  defp has_story?(user_id) do
    Accounts.Profile
    |> where(user_id: ^user_id)
    |> select([p], p.story)
    |> Repo.one()
    |> case do
      [] -> false
      nil -> false
      [_ | _] -> true
    end
  end

  @spec schedule_apns([%Accounts.APNSDevice{}], String.t(), map) :: [Oban.Job.t()]
  def schedule_apns(apns_devices, template, data) do
    apns_devices
    |> Enum.map(fn device ->
      %Accounts.APNSDevice{device_id: device_id, locale: locale, env: env, topic: topic} = device

      PushNotifications.APNSJob.new(%{
        "template" => template,
        "device_id" => device_id,
        "locale" => locale,
        "data" => data,
        "env" => env,
        "topic" => topic
      })
    end)
    # TODO might need to chunk later
    |> Oban.insert_all()
  end
end
