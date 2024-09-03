defmodule Since.PushNotifications.DispatchJob do
  # TODO unique per user id?
  # TODO remove all notifications when unmatched

  use Oban.Worker, queue: :apns
  import Ecto.Query
  alias Since.{Repo, Accounts, PushNotifications}

  @impl true
  def perform(%Oban.Job{args: %{"type" => type} = args}) do
    handle_type(type, args)
  end

  defp handle_type(type, %{"from_user_id" => from_user_id, "to_user_id" => to_user_id} = args)
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
    profile_from = profile_info(from_user_id)

    if profile_from do
      {name_from, gender_from} = profile_from
      data = args |> Map.merge(%{"name_from" => name_from, "gender_from" => gender_from})
      to_user_id |> Accounts.list_apns_devices() |> schedule_apns(type, data)
    end

    :ok
  end

  defp handle_type(
         "compliment_revealed" = type,
         %{"from_user_id" => from_user_id, "to_user_id" => to_user_id} = args
       ) do
    profile_from = profile_info(from_user_id)

    if profile_from do
      {name_from, gender_from} = profile_from
      data = args |> Map.merge(%{"name_from" => name_from, "gender_from" => gender_from})
      to_user_id |> Accounts.list_apns_devices() |> schedule_apns(type, data)
    end

    :ok
  end

  defp handle_type("compliment" = type, %{"to_user_id" => to_user_id} = args) do
    to_user_id |> Accounts.list_apns_devices() |> schedule_apns(type, args)

    :ok
  end

  defp handle_type(
         "private_page_available" = type,
         %{
           "for_user_id" => for_user_id,
           "of_user_id" => of_user_id
         } = args
       ) do
    profile_of = profile_info(of_user_id)

    if profile_of do
      {name_of, gender_of} = profile_of
      data = args |> Map.merge(%{"name_of" => name_of, "gender_of" => gender_of})
      for_user_id |> Accounts.list_apns_devices() |> schedule_apns(type, data)
    end
  end

  defp handle_type("complete_onboarding" = type, %{"user_id" => user_id} = args) do
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

  defp handle_type("compliment_limit_reset" = type, %{"user_id" => user_id} = args) do
    user_id |> Accounts.list_apns_devices() |> schedule_apns(type, args)
    :ok
  end

  defp profile_info(user_id) do
    Accounts.Profile
    |> where(user_id: ^user_id)
    |> select([p], {p.name, p.gender})
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
