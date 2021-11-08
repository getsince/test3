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
      %Matches.Match{user_id_1: uid1, user_id_2: uid2} = match

      data = %{"match_id" => match_id}
      uid1 |> Accounts.list_apns_devices() |> schedule_apns("match_about_to_expire", data)
      uid2 |> Accounts.list_apns_devices() |> schedule_apns("match_about_to_expire", data)

      :ok
    else
      :discard
    end
  end

  defp handle_type(type, args) when type in ["timeslot_offer", "timeslot_accepted"] do
    %{"match_id" => match_id, "receiver_id" => receiver_id} = args

    if alive_match(match_id) do
      receiver_id
      |> Accounts.list_apns_devices()
      |> schedule_apns(type, %{"match_id" => match_id})

      :ok
    else
      :discard
    end
  end

  defp handle_type("timeslot_accepted_now" = type, args) do
    %{"match_id" => match_id, "receiver_id" => receiver_id, "slot" => slot} = args

    if match = alive_match(match_id) do
      timeslot =
        Matches.Timeslot |> where(match_id: ^match_id, selected_slot: ^slot) |> Repo.one()

      if timeslot do
        Matches.schedule_timeslot_ended(match, timeslot)

        receiver_id
        |> Accounts.list_apns_devices()
        |> schedule_apns(type, %{"match_id" => match_id})

        :ok
      end
    end || :discard
  end

  defp handle_type(type, args) when type in ["timeslot_reminder", "timeslot_started"] do
    %{"match_id" => match_id, "slot" => slot} = args

    if match = alive_match(match_id) do
      timeslot =
        Matches.Timeslot |> where(match_id: ^match_id, selected_slot: ^slot) |> Repo.one()

      if timeslot do
        %Matches.Match{user_id_1: uid1, user_id_2: uid2} = match

        if type == "timeslot_started" do
          Matches.notify_timeslot_started(match)
          Matches.schedule_timeslot_ended(match, timeslot)
        end

        data = %{"match_id" => match_id}
        uid1 |> Accounts.list_apns_devices() |> schedule_apns(type, data)
        uid2 |> Accounts.list_apns_devices() |> schedule_apns(type, data)

        :ok
      end
    end || :discard
  end

  defp handle_type("timeslot_cancelled" = type, args) do
    %{"match_id" => match_id} = args

    if match = alive_match(match_id) do
      timeslot =
        Matches.Timeslot
        |> where(match_id: ^match_id)
        |> where([t], not is_nil(t.selected_slot))
        |> Repo.one()

      unless timeslot do
        %Matches.Match{user_id_1: uid1, user_id_2: uid2} = match

        data = %{"match_id" => match_id}
        uid1 |> Accounts.list_apns_devices() |> schedule_apns(type, data)
        uid2 |> Accounts.list_apns_devices() |> schedule_apns(type, data)

        :ok
      end
    end
  end

  defp handle_type("timeslot_ended", args) do
    %{"match_id" => match_id} = args

    match =
      Matches.Match
      |> where(id: ^match_id)
      |> Repo.one()

    Matches.notify_timeslot_ended(match)

    :ok
  end

  defp handle_type("invite" = type, args) do
    %{"by_user_id" => by_user_id, "user_id" => user_id} = args

    data = %{
      "user_id" => by_user_id,
      "name" => profile_name(by_user_id)
    }

    user_id |> Accounts.list_apns_devices() |> schedule_apns(type, data)

    :ok
  end

  defp handle_type("session_expired" = type, args) do
    %{"user_id" => user_id} = args

    user_id
    |> Accounts.list_apns_devices()
    |> schedule_apns(type, _data = %{})

    :ok
  end

  defp profile_name(user_id) do
    Accounts.Profile
    |> where(user_id: ^user_id)
    |> select([p], p.name)
    |> Repo.one()
  end

  defp alive_match(match_id) do
    Matches.Match
    |> where(id: ^match_id)
    |> Repo.one()
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
    |> Oban.insert_all()
  end
end
