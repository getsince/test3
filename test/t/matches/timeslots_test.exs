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
        Matches.save_slots_offer(@slots, match: match, from: p1.user_id, reference: @reference)
      end
    end

    test "with dead match", %{profiles: [p1, p2]} do
      match = insert(:match, user_id_1: p1.user_id, user_id_2: p2.user_id, alive?: false)

      assert_raise Ecto.NoResultsError, fn ->
        Matches.save_slots_offer(@slots, match: match.id, from: p1.user_id, reference: @reference)
      end
    end

    test "with match we are not part of", %{profiles: [p1, p2]} do
      p3 = insert(:profile, hidden?: false)
      match = insert(:match, user_id_1: p1.user_id, user_id_2: p2.user_id, alive?: true)

      assert_raise Ecto.NoResultsError, fn ->
        Matches.save_slots_offer(@slots, match: match.id, from: p3.user_id, reference: @reference)
      end
    end
  end

  describe "save_slots_offer/2" do
    setup [:with_profiles, :with_match]

    test "with empty slots", %{profiles: [p1, _], match: match} do
      assert {:error, :timeslot, %Ecto.Changeset{valid?: false} = changeset, %{}} =
               Matches.save_slots_offer([], match: match.id, from: p1.user_id)

      assert errors_on(changeset) == %{slots: ["should have at least 1 item(s)"]}
    end

    test "with all slots in the past", %{profiles: [p1, _], match: match} do
      slots = [
        "2021-03-23 13:15:00Z",
        "2021-03-23 13:30:00Z",
        "2021-03-23 13:45:00Z"
      ]

      assert {:error, :timeslot, %Ecto.Changeset{valid?: false} = changeset, %{}} =
               Matches.save_slots_offer(slots,
                 match: match.id,
                 from: p1.user_id,
                 reference: ~U[2021-03-23 14:00:00Z]
               )

      assert errors_on(changeset) == %{slots: ["should have at least 1 item(s)"]}
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

      assert {:ok, %{timeslot: %Timeslot{} = timeslot}} =
               Matches.save_slots_offer(slots,
                 match: match.id,
                 from: p1.user_id,
                 reference: ~U[2021-03-23 14:04:00Z]
               )

      assert timeslot.slots == [
               ~U[2021-03-23 14:00:00Z],
               ~U[2021-03-23 14:15:00Z],
               ~U[2021-03-23 14:30:00Z]
             ]

      assert timeslot.picker_id == p2.user_id
      refute timeslot.selected_slot
    end
  end

  describe "save_slots_offer/2 side-effects" do
    setup [:with_profiles]

    setup %{profiles: [_p1, p2]} do
      Matches.subscribe_for_user(p2.user_id)
    end

    setup [:with_match, :with_offer]

    test "push notification is scheduled for mate", %{
      profiles: [_p1, %{user_id: receiver_id}],
      match: %{id: match_id}
    } do
      assert [
               %Oban.Job{
                 args: %{
                   "match_id" => ^match_id,
                   "receiver_id" => ^receiver_id,
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

  describe "filter_relevant_slots/2" do
    test "filters slots in past" do
      # ~U[2021-03-23 14:00:00Z] = current slot
      referece = ~U[2021-03-23 14:12:00Z]

      timeslots = [
        %Timeslot{
          slots: [
            ~U[2021-03-23 13:45:00Z],
            ~U[2021-03-23 14:00:00Z],
            ~U[2021-03-23 14:15:00Z],
            ~U[2021-03-23 14:30:00Z]
          ]
        },
        %Timeslot{
          selected_slot: ~U[2021-03-23 13:45:00Z],
          slots: [~U[2021-03-23 13:45:00Z], ~U[2021-03-23 14:15:00Z], ~U[2021-03-23 14:30:00Z]]
        },
        %Timeslot{
          selected_slot: ~U[2021-03-23 14:15:00Z],
          slots: [~U[2021-03-23 13:45:00Z], ~U[2021-03-23 14:15:00Z], ~U[2021-03-23 14:30:00Z]]
        }
      ]

      assert [
               %Timeslot{
                 selected_slot: nil,
                 slots: [
                   ~U[2021-03-23 14:00:00Z],
                   ~U[2021-03-23 14:15:00Z],
                   ~U[2021-03-23 14:30:00Z]
                 ]
               },
               %Timeslot{
                 selected_slot: ~U[2021-03-23 14:15:00Z],
                 slots: [~U[2021-03-23 14:15:00Z], ~U[2021-03-23 14:30:00Z]]
               }
             ] = Matches.filter_relevant_slots(timeslots, referece)
    end
  end

  describe "list_relevant_slots/2" do
    setup [:with_profiles, :with_match]

    @tag skip: true
    test "stale slots are deleted"

    test "only slots for alive match are listed", %{profiles: [_p1, p2], match: match} do
      insert(:timeslot,
        slots: [~U[2021-03-23 14:00:00Z], ~U[2021-03-23 14:15:00Z]],
        match: match,
        picker: p2.user
      )

      assert [%Timeslot{slots: [~U[2021-03-23 14:00:00Z], ~U[2021-03-23 14:15:00Z]]}] =
               Matches.list_relevant_slots(p2.user_id, ~U[2021-03-23 14:00:00Z])

      p3 = insert(:profile, hidden?: false)
      dead_match = insert(:match, user_id_1: p2.user_id, user_id_2: p3.user_id, alive?: false)

      insert(:timeslot,
        slots: [~U[2021-03-23 14:15:00Z], ~U[2021-03-23 14:30:00Z]],
        match: dead_match,
        picker: p2.user
      )

      assert [%Timeslot{slots: [~U[2021-03-23 14:00:00Z], ~U[2021-03-23 14:15:00Z]]}] =
               Matches.list_relevant_slots(p2.user_id, ~U[2021-03-23 14:00:00Z])
    end
  end

  describe "accept_slot/2 for invalid match" do
    setup [:with_profiles]

    @slot "2021-03-23 14:45:00Z"
    @reference ~U[2021-03-23 14:00:00Z]

    test "with slot in the past" do
      assert_raise MatchError, fn ->
        Matches.accept_slot("2021-03-23 13:45:00Z", reference: @reference)
      end
    end

    test "with non-existent match", %{profiles: [_p1, p2]} do
      match = Ecto.UUID.generate()

      assert_raise Ecto.NoResultsError, fn ->
        Matches.accept_slot(@slot, match: match, picker: p2.user_id, reference: @reference)
      end
    end

    test "with dead match", %{profiles: [p1, p2]} do
      match = insert(:match, user_id_1: p1.user_id, user_id_2: p2.user_id, alive?: false)

      assert_raise Ecto.NoResultsError, fn ->
        Matches.accept_slot(@slot, match: match.id, picker: p1.user_id, reference: @reference)
      end
    end

    test "with match we are not part of", %{profiles: [p1, p2]} do
      p3 = insert(:profile, hidden?: false)
      match = insert(:match, user_id_1: p1.user_id, user_id_2: p2.user_id, alive?: true)

      assert_raise Ecto.NoResultsError, fn ->
        Matches.accept_slot(@slot, match: match.id, picker: p3.user_id, reference: @reference)
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
      assert {:ok, %Timeslot{} = timeslot} =
               Matches.accept_slot("2021-03-23 14:00:00Z",
                 match: match.id,
                 picker: p2.user_id,
                 reference: ~U[2021-03-23 14:05:12Z]
               )

      assert timeslot.selected_slot == ~U[2021-03-23 14:00:00Z]
    end

    test "accepts future slot", %{profiles: [_p1, p2], match: match} do
      assert {:ok, %Timeslot{} = timeslot} =
               Matches.accept_slot("2021-03-23 14:15:00Z",
                 match: match.id,
                 picker: p2.user_id,
                 reference: ~U[2021-03-23 14:05:00Z]
               )

      assert timeslot.selected_slot == ~U[2021-03-23 14:15:00Z]
    end
  end

  describe "accept_slot/2 side-effects" do
    setup [:with_profiles, :with_match, :with_offer]

    setup %{profiles: [p1, p2], match: match} do
      :ok = Matches.subscribe_for_user(p1.user_id)

      {:ok, %Timeslot{}} =
        Matches.accept_slot("2021-03-23 14:15:00Z",
          match: match.id,
          picker: p2.user_id,
          reference: ~U[2021-03-23 14:00:00Z]
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

    test "push notification are scheduled", %{
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
               },
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
    end

    @tag skip: true
    test "timeslot_reminder not scheduled for slots within 15 minutes from now"
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

      assert {:ok,
              %{timeslot: %Timeslot{slots: [~U[2021-03-23 14:30:00Z], ~U[2021-03-23 14:45:00Z]]}}} =
               Matches.save_slots_offer(["2021-03-23 14:30:00Z", "2021-03-23 14:45:00Z"],
                 match: match.id,
                 from: p2.user_id,
                 reference: ~U[2021-03-23 14:04:00Z]
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
              %{
                timeslot: %Timeslot{
                  slots: [~U[2021-03-23 14:30:00Z], ~U[2021-03-23 14:45:00Z]],
                  picker_id: ^new_picker,
                  selected_slot: nil
                }
              }} =
               Matches.save_slots_offer(["2021-03-23 14:30:00Z", "2021-03-23 14:45:00Z"],
                 match: match.id,
                 from: p2.user_id,
                 reference: ~U[2021-03-23 14:04:00Z]
               )
    end
  end

  defp with_profiles(_context) do
    {:ok, profiles: insert_list(2, :profile, hidden?: false)}
  end

  defp with_match(%{profiles: [p1, p2]}) do
    {:ok, match: insert(:match, user_id_1: p1.user_id, user_id_2: p2.user_id, alive?: true)}
  end

  defp with_offer(%{profiles: [p1, _p2], match: match}) do
    slots = [
      "2021-03-23 13:15:00Z",
      "2021-03-23 13:30:00Z",
      "2021-03-23 14:00:00Z",
      "2021-03-23 14:15:00Z",
      "2021-03-23 14:30:00Z"
    ]

    assert {:ok, %{timeslot: %Timeslot{} = timeslot}} =
             Matches.save_slots_offer(slots,
               match: match.id,
               from: p1.user_id,
               reference: ~U[2021-03-23 14:12:00Z]
             )

    {:ok, timeslot: timeslot}
  end
end
