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
      template_uid1 = if has_contact?(uid1), do: "match", else: "match_no_contact"
      template_uid2 = if has_contact?(uid2), do: "match", else: "match_no_contact"
      uid1 |> Accounts.list_apns_devices() |> schedule_apns(template_uid1, data)
      uid2 |> Accounts.list_apns_devices() |> schedule_apns(template_uid2, data)

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
          uid1 |> Accounts.list_apns_devices() |> schedule_apns("match_about_to_expire", data1)
          uid2 |> Accounts.list_apns_devices() |> schedule_apns("match_about_to_expire", data2)
        end
      end
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

  defp handle_type("contact_offer" = type, args) do
    %{"match_id" => match_id, "receiver_id" => receiver_id, "offerer_id" => offerer_id} = args

    if alive_match(match_id) do
      if profile = profile_info(offerer_id) do
        {name, gender} = profile

        receiver_id
        |> Accounts.list_apns_devices()
        |> schedule_apns(type, %{"match_id" => match_id, "name" => name, "gender" => gender})

        :ok
      end
    else
      :discard
    end
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

  defp has_contact?(user_id) do
    Accounts.Profile
    |> where(user_id: ^user_id)
    |> select([p], p.story)
    |> Repo.one()
    |> then(fn story -> story || [] end)
    |> Enum.any?(fn page ->
      Enum.any?(page["labels"] || [], fn label ->
        label["question"] in Accounts.Profile.contacts()
      end)
    end)
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
        "topic" => topic,
        "push_type" => "alert",
        "priority" => "10"
      })
    end)
    # TODO might need to chunk later
    |> Oban.insert_all()
  end
end
