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

  def populate_match_interactions(dry_run \\ true) do
    import Ecto.Query
    alias T.{Repo, Calls, Matches}
    alias Calls.{Call, Voicemail}
    alias Matches.{Match, Interaction, MatchContact, Timeslot}

    # calls

    calls_1_q =
      Call
      |> join(:inner, [c], m in Match,
        on: m.user_id_1 == c.caller_id and m.user_id_2 == c.called_id
      )
      |> select([c, m], %{call: c, match_id: m.id})

    calls_2_q =
      Call
      |> join(:inner, [c], m in Match,
        on: m.user_id_2 == c.caller_id and m.user_id_1 == c.called_id
      )
      |> select([c, m], %{call: c, match_id: m.id})

    calls =
      calls_1_q
      |> union(^calls_2_q)
      |> Repo.all()
      |> Enum.map(fn %{call: call, match_id: match_id} ->
        %Call{
          id: id,
          caller_id: caller,
          called_id: called,
          accepted_at: accepted_at,
          ended_at: ended_at
        } = call

        %Interaction{
          id: id,
          match_id: match_id,
          from_user_id: caller,
          to_user_id: called,
          data:
            %{"type" => "call"}
            |> maybe_put("accepted_at", accepted_at)
            |> maybe_put("ended_at", ended_at)
        }
      end)

    # voicemail

    voicemail =
      Voicemail
      |> join(:inner, [v], m in Match, on: v.match_id == m.id)
      |> select([v, m], %{voicemail: v, mates: [m.user_id_1, m.user_id_2]})
      |> Repo.all()
      |> Enum.map(fn %{voicemail: voicemail, mates: mates} ->
        [mate] = mates -- [voicemail.caller_id]

        %Interaction{
          id: voicemail.id,
          from_user_id: voicemail.caller_id,
          to_user_id: mate,
          match_id: voicemail.match_id,
          data: %{"type" => "voicemail", "s3" => voicemail.s3_key}
        }
      end)

    # contact offers

    contacts =
      MatchContact
      |> join(:inner, [c], m in Match, on: c.match_id == m.id)
      |> select([c, m], %{contact: c, mates: [m.user_id_1, m.user_id_2]})
      |> Repo.all()
      |> Enum.map(fn %{contact: contact, mates: mates} ->
        [sender] = mates -- [contact.picker_id]

        %Interaction{
          id: fake_id(contact.inserted_at),
          data: %{"type" => "contact_offer", "contacts" => contact.contacts},
          match_id: contact.match_id,
          from_user_id: sender,
          to_user_id: contact.picker_id
        }
      end)

    # slots offers / accepts

    slots =
      Timeslot
      |> join(:inner, [t], m in Match, on: t.match_id == m.id)
      |> select([t, m], %{timeslot: t, mates: [m.user_id_1, m.user_id_2]})
      |> Repo.all()
      |> Enum.flat_map(fn %{timeslot: timeslot, mates: mates} ->
        [offerer] = mates -- [timeslot.picker_id]

        offer = %Interaction{
          id: fake_id(timeslot.inserted_at),
          from_user_id: offerer,
          to_user_id: timeslot.picker_id,
          match_id: timeslot.match_id,
          data: %{"type" => "slots_offer", "slots" => timeslot.slots}
        }

        if timeslot.selected_slot && timeslot.accepted_at do
          accept = %Interaction{
            id: fake_id(timeslot.accepted_at),
            from_user_id: timeslot.picker_id,
            to_user_id: offerer,
            match_id: timeslot.match_id,
            data: %{"type" => "slot_accept", "slot" => timeslot.selected_slot}
          }

          [offer, accept]
        else
          [offer]
        end
      end)

    interactions =
      (calls ++ voicemail ++ contacts ++ slots)
      |> Enum.map(&Map.take(&1, Interaction.__schema__(:fields)))
      |> Enum.sort_by(& &1.id, :asc)

    if dry_run do
      interactions
    else
      insert_opts = [on_conflict: :replace_all, conflict_target: :id, returning: true]
      Repo.insert_all(Interaction, interactions, insert_opts)
    end
  end

  defp fake_id(datetime, id_example \\ "0000017a-a0f0-c00e-0242-ac1100040000")

  defp fake_id(datetime, <<_::288>> = uuid) do
    fake_id(datetime, Ecto.Bigflake.UUID.dump!(uuid))
  end

  defp fake_id(datetime, <<_ts::64, rest::64>> = _id_example) do
    ts =
      datetime
      |> case do
        %DateTime{} -> datetime
        %NaiveDateTime{} -> DateTime.from_naive!(datetime, "Etc/UTC")
      end
      |> DateTime.to_unix(:millisecond)

    Ecto.Bigflake.UUID.cast!(<<ts::64, rest::64>>)
  end

  defp maybe_put(map, _k, nil), do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)
end
