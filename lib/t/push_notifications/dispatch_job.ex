defmodule T.PushNotifications.DispatchJob do
  # TODO unique per user id?
  # TODO remove all notifications when unmatched

  use Oban.Worker, queue: :apns
  import Ecto.Query
  alias T.{Repo, Matches, PushNotifications}

  @impl true
  def perform(%Oban.Job{args: %{"type" => type} = args}) do
    handle_type(type, args)
  end

  defp handle_type("match", args) do
    %{"match_id" => match_id} = args

    if match = alive_match(match_id) do
      %Matches.Match{user_id_1: uid1, user_id_2: uid2} = match

      uid1 |> Matches.device_ids() |> schedule_apns("match")
      uid2 |> Matches.device_ids() |> schedule_apns("match")

      :ok
    else
      :discard
    end
  end

  defp handle_type("message", args) do
    %{"match_id" => match_id, "author_id" => author_id} = args

    if match = alive_match(match_id) do
      %Matches.Match{user_id_1: uid1, user_id_2: uid2} = match

      [receiver_id] = [uid1, uid2] -- [author_id]
      receiver_id |> Matches.device_ids() |> schedule_apns("message")

      :ok
    else
      :discard
    end
  end

  # TODO remove, yos are not schedulable
  # defp handle_type("yo", args) do
  #   %{"match_id" => match_id, "sender_id" => sender_id} = args

  #   if match = alive_match(match_id) do
  #     %Matches.Match{user_id_1: uid1, user_id_2: uid2} = match

  #     [receiver_id] = [uid1, uid2] -- [sender_id]
  #     # TODO if not devices -> send SMS

  #     receiver_id
  #     |> Matches.device_ids()
  #     |> schedule_apns("yo", %{"sender_name" => Matches.profile_name(sender_id)})

  #     :ok
  #   else
  #     :discard
  #   end
  # end

  defp handle_type("support", args) do
    %{"user_id" => user_id} = args
    user_id |> Matches.device_ids() |> schedule_apns("support")
    :ok
  end

  defp handle_type(type, args) when type in ["timeslot_offer", "timeslot_accepted"] do
    %{"match_id" => match_id, "receiver_id" => receiver_id} = args

    if alive_match(match_id) do
      receiver_id |> Matches.device_ids() |> schedule_apns(type)
      :ok
    else
      :discard
    end
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

        uid1 |> Matches.device_ids() |> schedule_apns(type)
        uid2 |> Matches.device_ids() |> schedule_apns(type)

        :ok
      end
    end || :discard
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

  defp alive_match(match_id) do
    Matches.Match
    |> where(id: ^match_id)
    |> where(alive?: true)
    |> Repo.one()
  end

  defp schedule_apns(device_ids, template, data \\ %{}) do
    device_ids
    |> Enum.map(fn device_id ->
      PushNotifications.APNSJob.new(%{
        "template" => template,
        "device_id" => Base.encode16(device_id),
        "data" => data
      })
    end)
    |> Oban.insert_all()
  end
end
