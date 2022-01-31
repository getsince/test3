defmodule T.Matches.TimeslotsTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: T.Repo

  alias T.Matches
  alias T.Matches.Timeslot

  describe "save_slots_offer/2 for invalid match" do
    setup [:with_profiles]

    @slots [
      "2021-03-23 14:45:00Z",
      "2021-03-23 15:00:00Z",
      "2021-03-23 15:15:00Z"
    ]

    @reference ~U[2021-03-23 14:00:00Z]

    test "with non-existent match", %{profiles: [p1, _]} do
      match = Ecto.UUID.generate()

      assert_raise Ecto.NoResultsError, fn ->
        Matches.save_slots_offer_for_match(p1.user_id, match, @slots, @reference)
      end
    end

    test "with match we are not part of", %{profiles: [p1, p2]} do
      p3 = insert(:profile, hidden?: false)
      match = insert(:match, user_id_1: p1.user_id, user_id_2: p2.user_id)

      assert_raise Ecto.NoResultsError, fn ->
        Matches.save_slots_offer_for_match(p3.user_id, match.id, @slots, @reference)
      end

      match_event = Matches.MatchEvent |> T.Repo.all()

      assert length(match_event) == 0
    end
  end

  describe "save_slots_offer/2" do
    setup [:with_profiles, :with_match]

    test "with empty slots", %{profiles: [p1, _], match: match} do
      assert {:error, %Ecto.Changeset{valid?: false} = changeset} =
               Matches.save_slots_offer_for_match(p1.user_id, match.id, _slots = [])

      assert errors_on(changeset) == %{slots: ["should have at least 1 item(s)"]}
    end

    test "with all slots in the past", %{profiles: [p1, _], match: match} do
      slots = [
        "2021-03-23 13:15:00Z",
        "2021-03-23 13:30:00Z",
        "2021-03-23 13:45:00Z"
      ]

      assert {:error, %Ecto.Changeset{valid?: false} = changeset} =
               Matches.save_slots_offer_for_match(
                 p1.user_id,
                 match.id,
                 slots,
                 _reference = ~U[2021-03-23 14:00:00Z]
               )

      assert errors_on(changeset) == %{slots: ["should have at least 1 item(s)"]}

      match_event = Matches.MatchEvent |> T.Repo.all()

      assert length(match_event) == 0
    end

    test "slots in the past are filtered", %{profiles: [p1, p2], match: match} do
      slots = [
        "2021-03-23 13:15:00Z",
        "2021-03-23 13:30:00Z",
        # current slot
        "2021-03-23 14:00:00Z",
        "2021-03-23 14:15:00Z",
        "2021-03-23 14:30:00Z"
      ]

      assert {:ok, %Timeslot{} = timeslot} =
               Matches.save_slots_offer_for_match(
                 p1.user_id,
                 match.id,
                 slots,
                 _reference = ~U[2021-03-23 14:04:00Z]
               )

      assert timeslot.slots == [
               ~U[2021-03-23 14:00:00Z],
               ~U[2021-03-23 14:15:00Z],
               ~U[2021-03-23 14:30:00Z]
             ]

      assert timeslot.picker_id == p2.user_id
      refute timeslot.selected_slot
    end

    test "saves and broadcasts slots_offer interaction", %{profiles: [p1, p2], match: match} do
      Matches.subscribe_for_user(p1.user_id)
      Matches.subscribe_for_user(p2.user_id)

      slots = [
        "2021-03-23 13:15:00Z",
        "2021-03-23 13:30:00Z",
        # current slot
        "2021-03-23 14:00:00Z",
        "2021-03-23 14:15:00Z",
        "2021-03-23 14:30:00Z"
      ]

      assert {:ok, _timeslot} =
               Matches.save_slots_offer_for_match(
                 p1.user_id,
                 match.id,
                 slots,
                 _reference = ~U[2021-03-23 14:04:00Z]
               )

      # interaction includes only future slots too
      assert [i1] = Matches.history_list_interactions(match.id)
      assert i1.from_user_id == p1.user_id
      assert i1.to_user_id == p2.user_id
      assert i1.match_id == match.id

      assert i1.data == %{
               "type" => "slots_offer",
               "slots" => [
                 "2021-03-23T14:00:00Z",
                 "2021-03-23T14:15:00Z",
                 "2021-03-23T14:30:00Z"
               ]
             }

      assert_received {Matches, :interaction, %Matches.Interaction{} = interaction}

      assert interaction.data == %{
               "type" => "slots_offer",
               "slots" => [
                 ~U[2021-03-23 14:00:00Z],
                 ~U[2021-03-23 14:15:00Z],
                 ~U[2021-03-23 14:30:00Z]
               ]
             }

      assert_received {Matches, :interaction, ^interaction}
    end
  end

  describe "save_slots_offer/2 side-effects" do
    setup [:with_profiles]

    setup %{profiles: [_p1, p2]} do
      Matches.subscribe_for_user(p2.user_id)
    end

    setup [:with_match, :with_offer]

    test "push notification is scheduled for mate", %{
      profiles: [%{user_id: offerer_id}, %{user_id: receiver_id}],
      match: %{id: match_id}
    } do
      assert [
               %Oban.Job{
                 args: %{
                   "match_id" => ^match_id,
                   "receiver_id" => ^receiver_id,
                   "offerer_id" => ^offerer_id,
                   "type" => "timeslot_offer"
                 }
               }
             ] = all_enqueued(worker: T.PushNotifications.DispatchJob)
    end

    test "offer is broadcast via pubsub to mate", %{profiles: [_p1, %{user_id: receiver_id}]} do
      assert_receive {Matches, [:timeslot, :offered], %Timeslot{} = timeslot}

      assert timeslot.slots == [
               ~U[2021-03-23 14:00:00Z],
               ~U[2021-03-23 14:15:00Z],
               ~U[2021-03-23 14:30:00Z]
             ]

      assert timeslot.picker_id == receiver_id
      refute timeslot.selected_slot
    end
  end

  describe "accept_slot/2 for invalid match" do
    setup [:with_profiles]

    @slot "2021-03-23 14:45:00Z"
    @reference ~U[2021-03-23 14:00:00Z]

    test "with slot in the past", %{profiles: [p1, p2]} do
      match = insert(:match, user_id_1: p1.user_id, user_id_2: p2.user_id)

      assert_raise MatchError, fn ->
        Matches.accept_slot_for_match(
          p2.user_id,
          match.id,
          _slot = "2021-03-23 13:45:00Z",
          @reference
        )
      end
    end

    test "with non-existent match", %{profiles: [_p1, p2]} do
      match = Ecto.UUID.generate()

      assert_raise Ecto.NoResultsError, fn ->
        Matches.accept_slot_for_match(p2.user_id, match, @slot, @reference)
      end
    end

    test "with match we are not part of", %{profiles: [p1, p2]} do
      p3 = insert(:profile, hidden?: false)
      match = insert(:match, user_id_1: p1.user_id, user_id_2: p2.user_id)

      assert_raise Ecto.NoResultsError, fn ->
        Matches.accept_slot_for_match(p3.user_id, match.id, @slot, @reference)
      end
    end

    @tag skip: true
    test "without offer"

    @tag skip: true
    test "with slot not in offer"
  end

  describe "accept_slot/2" do
    setup [:with_profiles, :with_match, :with_offer]

    test "accepts current slot", %{profiles: [_p1, p2], match: match} do
      assert %Timeslot{} =
               timeslot =
               Matches.accept_slot_for_match(
                 p2.user_id,
                 match.id,
                 _slot = "2021-03-23 14:00:00Z",
                 _reference = ~U[2021-03-23 14:05:12Z]
               )

      assert timeslot.selected_slot == ~U[2021-03-23 14:00:00Z]
    end

    test "accepts future slot", %{profiles: [_p1, p2], match: match} do
      assert %Timeslot{} =
               timeslot =
               Matches.accept_slot_for_match(
                 p2.user_id,
                 match.id,
                 _slot = "2021-03-23 14:15:00Z",
                 _reference = ~U[2021-03-23 14:05:00Z]
               )

      assert timeslot.selected_slot == ~U[2021-03-23 14:15:00Z]

      match_event = Matches.MatchEvent |> T.Repo.all()

      assert length(match_event) == 2
    end

    test "saves and broadcasts `slot_accept` interaction", %{profiles: [p1, p2], match: match} do
      Matches.subscribe_for_user(p1.user_id)
      Matches.subscribe_for_user(p2.user_id)

      assert %Timeslot{} =
               Matches.accept_slot_for_match(
                 p2.user_id,
                 match.id,
                 _slot = "2021-03-23 14:00:00Z",
                 _reference = ~U[2021-03-23 14:05:12Z]
               )

      assert [i1, i2] = Matches.history_list_interactions(match.id)

      assert %{"type" => "slots_offer"} = i1.data

      assert i2.from_user_id == p2.user_id
      assert i2.to_user_id == p1.user_id
      assert i2.match_id == match.id

      assert i2.data == %{
               "type" => "slot_accept",
               "slot" => "2021-03-23T14:00:00Z"
             }

      assert_received {Matches, :interaction, %Matches.Interaction{} = interaction}

      assert interaction.data == %{"type" => "slot_accept", "slot" => ~U[2021-03-23 14:00:00Z]}

      assert_received {Matches, :interaction, ^interaction}
    end
  end

  describe "accept_slot/2 side-effects when slot in future" do
    setup [:with_profiles, :with_match, :with_offer]

    setup %{profiles: [p1, p2], match: match} do
      :ok = Matches.subscribe_for_user(p1.user_id)

      %Timeslot{} =
        Matches.accept_slot_for_match(
          p2.user_id,
          match.id,
          _slot = "2021-03-23 14:15:00Z",
          _reference = ~U[2021-03-23 14:00:00Z]
        )

      :ok
    end

    test "accept broadcasted via pubsub to mate" do
      assert_receive {Matches, [:timeslot, :accepted], %Timeslot{} = timeslot}

      assert timeslot.slots == [
               ~U[2021-03-23 14:00:00Z],
               ~U[2021-03-23 14:15:00Z],
               ~U[2021-03-23 14:30:00Z]
             ]

      assert timeslot.match_id
      assert timeslot.selected_slot == ~U[2021-03-23 14:15:00Z]
    end

    test "push notifications are scheduled", %{
      match: %{id: match_id},
      profiles: [%{user_id: u1}, %{user_id: u2}]
    } do
      assert [
               %Oban.Job{
                 args: %{
                   "match_id" => ^match_id,
                   "slot" => "2021-03-23T14:15:00Z",
                   "type" => "timeslot_started"
                 },
                 scheduled_at: ~U[2021-03-23 14:15:00.000000Z]
               } = started,
               %Oban.Job{
                 args: %{
                   "match_id" => ^match_id,
                   "slot" => "2021-03-23T14:15:00Z",
                   "type" => "timeslot_reminder"
                 },
                 #  15 mins before slot
                 scheduled_at: ~U[2021-03-23 14:00:00.000000Z]
               },
               %Oban.Job{
                 args: %{
                   "match_id" => ^match_id,
                   "receiver_id" => ^u1,
                   "type" => "timeslot_accepted"
                 }
               },
               %Oban.Job{
                 args: %{
                   "match_id" => ^match_id,
                   "receiver_id" => ^u2,
                   "type" => "timeslot_offer"
                 }
               }
             ] = all_enqueued(worker: T.PushNotifications.DispatchJob)

      assert :ok == T.PushNotifications.DispatchJob.perform(started)
      assert_receive {T.Matches, [:timeslot, :started], ^match_id}

      assert [
               #  60 mins after slot
               %Oban.Job{
                 args: %{
                   "match_id" => ^match_id,
                   "type" => "timeslot_ended"
                 },
                 scheduled_at: ~U[2021-03-23 15:15:00.000000Z]
               } = ended
               | _rest
             ] = all_enqueued(worker: T.PushNotifications.DispatchJob)

      assert :ok == T.PushNotifications.DispatchJob.perform(ended)
      assert_receive {T.Matches, [:timeslot, :ended], ^match_id}
    end

    @tag skip: true
    test "timeslot_reminder not scheduled for slots within 15 minutes from now"
  end

  describe "accept_slot/2 side-effects when slot has started" do
    setup [:with_profiles, :with_match, :with_offer]

    setup %{profiles: [p1, p2], match: match} do
      :ok = Matches.subscribe_for_user(p1.user_id)

      %Timeslot{} =
        Matches.accept_slot_for_match(
          p2.user_id,
          match.id,
          _slot = "2021-03-23 14:00:00Z",
          _reference = ~U[2021-03-23 14:12:00Z]
        )

      :ok
    end

    test "start broadcasted via pubsub to mate", %{match: %{id: match_id}} do
      assert_receive {T.Matches, [:timeslot, :started], ^match_id}
    end

    test "push notifications are scheduled", %{
      match: %{id: match_id},
      profiles: [%{user_id: u1}, %{user_id: u2}]
    } do
      assert [
               %Oban.Job{
                 args: %{
                   "match_id" => ^match_id,
                   "receiver_id" => ^u1,
                   "type" => "timeslot_accepted_now"
                 }
               } = accepted_now,
               %Oban.Job{
                 args: %{
                   "match_id" => ^match_id,
                   "receiver_id" => ^u2,
                   "type" => "timeslot_offer"
                 }
               }
             ] = all_enqueued(worker: T.PushNotifications.DispatchJob)

      assert :ok == T.PushNotifications.DispatchJob.perform(accepted_now)

      assert [
               #  60 mins after slot
               %Oban.Job{
                 args: %{
                   "match_id" => ^match_id,
                   "type" => "timeslot_ended"
                 },
                 scheduled_at: ~U[2021-03-23 15:00:00.000000Z]
               } = ended
               | _rest
             ] = all_enqueued(worker: T.PushNotifications.DispatchJob)

      assert :ok == T.PushNotifications.DispatchJob.perform(ended)
      assert_receive {T.Matches, [:timeslot, :ended], ^match_id}
    end
  end

  describe "counter-offer" do
    setup [:with_profiles, :with_match]

    test "on counter-offer, slots are overwritten", %{profiles: [_p1, p2], match: match} do
      assert %Timeslot{selected_slot: nil} =
               insert(:timeslot,
                 slots: [~U[2021-03-23 14:00:00Z], ~U[2021-03-23 14:15:00Z]],
                 match: match,
                 picker: p2.user
               )

      assert {:ok, %Timeslot{slots: [~U[2021-03-23 14:30:00Z], ~U[2021-03-23 14:45:00Z]]}} =
               Matches.save_slots_offer_for_match(
                 p2.user_id,
                 match.id,
                 ["2021-03-23 14:30:00Z", "2021-03-23 14:45:00Z"],
                 _reference = ~U[2021-03-23 14:04:00Z]
               )
    end

    test "on counter-offer, selected_slot is nullified", %{
      profiles: [%{user_id: new_picker}, p2],
      match: match
    } do
      assert %Timeslot{selected_slot: ~U[2021-03-23 14:00:00Z]} =
               insert(:timeslot,
                 slots: [~U[2021-03-23 14:00:00Z], ~U[2021-03-23 14:15:00Z]],
                 selected_slot: ~U[2021-03-23 14:00:00Z],
                 match: match,
                 picker: p2.user
               )

      assert {:ok,
              %Timeslot{
                slots: [~U[2021-03-23 14:30:00Z], ~U[2021-03-23 14:45:00Z]],
                picker_id: ^new_picker,
                selected_slot: nil
              }} =
               Matches.save_slots_offer_for_match(
                 p2.user_id,
                 match.id,
                 ["2021-03-23 14:30:00Z", "2021-03-23 14:45:00Z"],
                 ~U[2021-03-23 14:04:00Z]
               )
    end
  end

  describe "cancel-slot" do
    setup [:with_profiles, :with_match, :with_offer]

    test "saves and broadcasts `slot_cancel` interaction", %{profiles: [p1, p2], match: match} do
      Matches.subscribe_for_user(p1.user_id)
      Matches.subscribe_for_user(p2.user_id)

      assert :ok = Matches.cancel_slot_for_match(p1.user_id, match.id)

      assert [i1, i2] = Matches.history_list_interactions(match.id)

      assert %{"type" => "slots_offer"} = i1.data

      assert i2.from_user_id == p1.user_id
      assert i2.to_user_id == p2.user_id
      assert i2.match_id == match.id
      assert i2.data == %{"type" => "slot_cancel"}

      assert_received {Matches, :interaction, ^i2}
      assert_received {Matches, :interaction, ^i2}
    end
  end

  defp with_profiles(_context) do
    {:ok, profiles: insert_list(2, :profile, hidden?: false)}
  end

  defp with_match(%{profiles: [p1, p2]}) do
    {:ok, match: insert(:match, user_id_1: p1.user_id, user_id_2: p2.user_id)}
  end

  defp with_offer(%{profiles: [p1, _p2], match: match}) do
    slots = [
      "2021-03-23 13:15:00Z",
      "2021-03-23 13:30:00Z",
      "2021-03-23 14:00:00Z",
      "2021-03-23 14:15:00Z",
      "2021-03-23 14:30:00Z"
    ]

    assert {:ok, %Timeslot{} = timeslot} =
             Matches.save_slots_offer_for_match(
               p1.user_id,
               match.id,
               slots,
               _reference = ~U[2021-03-23 14:12:00Z]
             )

    {:ok, timeslot: timeslot}
  end
end
