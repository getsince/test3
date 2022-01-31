defmodule T.CallsTest do
  use T.DataCase, async: true

  alias T.{Calls, Matches}

  import Mox
  setup :verify_on_exit!

  # these are already tested through feed_channel_test
  # TODO still test directly later

  describe "call/2" do
    @tag skip: true
    test "when not allowed"
    @tag skip: true
    test "call matched"
    @tag skip: true
    test "when caller is invited by called"
    @tag skip: true
    test "when missed call"
    @tag skip: true
    test "when no pushkit devices"
    @tag skip: true
    test "when push fails"

    test "success: creates and broadcasts `call_attempt` interaction if users are matched" do
      me = onboarded_user()
      mate = onboarded_user()

      insert(:push_kit_device,
        device_id: "ABAB",
        user: mate,
        token: build(:user_token, user: mate)
      )

      match = insert(:match, user_id_1: me.id, user_id_2: mate.id)

      expect(MockAPNS, :push, fn _notification -> :ok end)

      Matches.subscribe_for_user(mate.id)
      Matches.subscribe_for_user(me.id)

      assert {:ok, call_id} = Calls.call(me.id, mate.id)

      assert [interaction] = Matches.history_list_interactions(match.id)

      assert interaction.id == call_id
      assert interaction.data == %{"type" => "call_attempt"}
      assert interaction.from_user_id == me.id
      assert interaction.to_user_id == mate.id
      assert interaction.match_id == match.id

      assert_received {Matches, :interaction, ^interaction}
      assert_received {Matches, :interaction, ^interaction}
    end

    test "success: doesn't create interaction if users are not matched" do
      me = onboarded_user()
      mate = onboarded_user()

      insert(:push_kit_device,
        device_id: "ABAB",
        user: mate,
        token: build(:user_token, user: mate)
      )

      expect(MockAPNS, :push, fn _notification -> :ok end)

      # in live mode all calls go through
      now = ~U[2022-02-03 16:30:00Z]
      assert {:ok, call_id} = Calls.call(me.id, mate.id, now)

      refute Repo.get(Matches.Interaction, call_id)
    end
  end

  describe "accept_call/2" do
    test "success: creates and broadcasts `call_accepted` interaction" do
      # me -call> mate
      me = onboarded_user()
      mate = onboarded_user()

      insert(:push_kit_device,
        device_id: "ABAB",
        user: mate,
        token: build(:user_token, user: mate)
      )

      match = insert(:match, user_id_1: me.id, user_id_2: mate.id)

      expect(MockAPNS, :push, fn _notification -> :ok end)

      Matches.subscribe_for_user(mate.id)
      Matches.subscribe_for_user(me.id)

      assert {:ok, call_id} = Calls.call(me.id, mate.id)
      assert [i1] = Matches.history_list_interactions(match.id)

      assert_received {Matches, :interaction, ^i1}
      assert_received {Matches, :interaction, ^i1}

      # mate -accept> me
      assert :ok == Calls.accept_call(call_id)
      assert [^i1, i2] = Matches.history_list_interactions(match.id)

      assert i2.data == %{"type" => "call_accepted", "call_id" => call_id}
      assert i2.from_user_id == mate.id
      assert i2.to_user_id == me.id
      assert i2.match_id == match.id

      assert_received {Matches, :interaction, ^i2}
      assert_received {Matches, :interaction, ^i2}
    end
  end

  describe "get_call_role_and_peer/2" do
    @tag skip: true
    test "when caller"
    @tag skip: true
    test "when called"
    @tag skip: true
    test "when not allowed"
  end

  describe "end_call/1" do
    @tag skip: true
    test "sets ended_at on call"
  end

  describe "list_missed_calls_with_profile/1" do
    @tag skip: true
    test "lists calls without accepted_at"
  end
end
