defmodule TWeb.FeedChannelTest do
  use TWeb.ChannelCase
  import Assertions

  alias T.{Feeds, Accounts, Calls, Matches}
  alias Matches.{Timeslot, Match}
  alias Calls.Call
  alias Pigeon.APNS.Notification

  import Mox
  setup :verify_on_exit!

  setup do
    me = onboarded_user(location: moscow_location(), accept_genders: ["F", "N", "M"])
    {:ok, me: me, socket: connected_socket(me)}
  end

  describe "join" do
    test "returns no current session if there's none", %{socket: socket, me: me} do
      assert {:ok, reply, _socket} = join(socket, "feed:" <> me.id)
      assert reply == %{}
    end

    @reference ~U[2021-07-21 11:55:18.941048Z]

    test "returns current session if there is one", %{socket: socket, me: me} do
      %{flake: id} = Feeds.activate_session(me.id, _duration = 60, @reference)
      assert {:ok, reply, _socket} = join(socket, "feed:" <> me.id)
      assert reply == %{"current_session" => %{id: id, expires_at: ~U[2021-07-21 12:55:18Z]}}
    end

    test "with matches", %{socket: socket, me: me} do
      [p1, p2, p3] =
        mates = [
          onboarded_user(story: [], name: "mate-1", location: apple_location(), gender: "F"),
          onboarded_user(story: [], name: "mate-2", location: apple_location(), gender: "N"),
          onboarded_user(story: [], name: "mate-3", location: apple_location(), gender: "M")
        ]

      [m1, m2, m3] =
        for mate <- mates do
          insert(:match, user_id_1: me.id, user_id_2: mate.id)
        end

      # if it's 14:47 right now ...
      %DateTime{hour: next_hour} = dt = DateTime.utc_now() |> DateTime.add(_seconds = 3600)
      date = DateTime.to_date(dt)

      # ... then the slots are
      slots = [
        # 15:15
        DateTime.new!(date, Time.new!(next_hour, 15, 0)),
        # 15:30
        s2 = DateTime.new!(date, Time.new!(next_hour, 30, 0)),
        # 15:45
        DateTime.new!(date, Time.new!(next_hour, 45, 0))
      ]

      insert(:timeslot, match_id: m2.id, slots: slots, picker_id: me.id)
      insert(:timeslot, match_id: m3.id, slots: slots, selected_slot: s2, picker_id: p3.id)
      assert {:ok, %{"matches" => matches}, _socket} = join(socket, "feed:" <> me.id)

      assert_lists_equal(matches, [
        %{
          "id" => m1.id,
          "profile" => %{name: "mate-1", story: [], user_id: p1.id, gender: "F"}
        },
        %{
          "id" => m2.id,
          "profile" => %{name: "mate-2", story: [], user_id: p2.id, gender: "N"},
          "timeslot" => %{"picker" => me.id, "slots" => slots}
        },
        %{
          "id" => m3.id,
          "profile" => %{name: "mate-3", story: [], user_id: p3.id, gender: "M"},
          "timeslot" => %{"selected_slot" => s2}
        }
      ])
    end

    test "when matched with mate", %{me: me, mate: mate, socket: socket} do
      insert(:match, user_id_1: me.id, user_id_2: mate.id)

      # these are the pushes sent to mate
      MockAPNS
      # ABABABAB on prod -> success!
      |> expect(:push, fn [%Notification{} = n], :prod ->
        [%Notification{n | response: :success}]
      end)
      # BABABABABA on sandbox -> fails!
      |> expect(:push, fn [%Notification{} = n], :dev ->
        [%Notification{n | response: :bad_device_token}]
      end)

      ref = push(socket, "call", %{"user_id" => mate.id})
      assert_reply(ref, :ok, %{"call_id" => call_id})

      assert %Call{id: ^call_id} = call = Repo.get!(Calls.Call, call_id)

      refute call.ended_at
      refute call.accepted_at
      assert call.caller_id == me.id
      assert call.called_id == mate.id
    end
  end

  describe "like" do
    setup :joined

    setup do
      {:ok, mate: onboarded_user(story: [], location: apple_location(), name: "mate")}
    end

    setup :joined_mate

    test "when already liked by mate", %{
      me: me,
      socket: socket,
      mate: mate,
      mate_socket: mate_socket
    } do
      # mate likes us
      ref = push(mate_socket, "like", %{"user_id" => me.id})
      assert_reply(ref, :ok, reply)
      assert reply == %{}

      # now it's our turn
      ref = push(socket, "like", %{"user_id" => mate.id})
      assert_reply(ref, :ok, %{"match_id" => match_id})
      assert is_binary(match_id)
    end

    test "when not yet liked by mate", %{
      me: me,
      socket: socket,
      mate: mate,
      mate_socket: mate_socket
    } do
      # we like mate
      ref = push(socket, "like", %{"user_id" => mate.id})
      assert_reply(ref, :ok, reply)
      assert reply == %{}

      # now mate likes us
      ref = push(mate_socket, "like", %{"user_id" => me.id})
      assert_reply(ref, :ok, %{"match_id" => match_id})
      assert is_binary(match_id)

      assert_push("matched", push)

      assert push == %{
               "match" => %{
                 "id" => match_id,
                 "profile" => %{name: "mate", story: [], user_id: mate.id, gender: "M"}
               }
             }
    end
  end

  # TODO re-offer
  describe "offer-slots success" do
    setup :joined

    setup %{me: me} do
      mate = onboarded_user(story: [], location: apple_location(), name: "mate")
      match = insert(:match, user_id_1: me.id, user_id_2: mate.id)

      # if it's 14:47 right now, then the slots are
      %DateTime{hour: next_hour} = dt = DateTime.utc_now() |> DateTime.add(_seconds = 3600)
      date = DateTime.to_date(dt)

      slots = [
        # 15:15
        DateTime.new!(date, Time.new!(next_hour, 15, 0)),
        # 15:30
        DateTime.new!(date, Time.new!(next_hour, 30, 0)),
        # 15:45
        DateTime.new!(date, Time.new!(next_hour, 45, 0))
      ]

      {:ok, mate: mate, match: match, slots: slots}
    end

    setup :joined_mate

    test "with match_id", %{slots: slots, match: match, socket: socket} do
      ref =
        push(socket, "offer-slots", %{
          "match_id" => match.id,
          "slots" => Enum.map(slots, &DateTime.to_iso8601/1)
        })

      assert_reply(ref, :ok, %{})

      # mate received slots
      assert_push("slots_offer", push)
      assert push == %{"match_id" => match.id, "slots" => slots}
    end

    test "with user_id", %{slots: slots, mate: mate, match: match, socket: socket} do
      ref =
        push(socket, "offer-slots", %{
          "user_id" => mate.id,
          "slots" => Enum.map(slots, &DateTime.to_iso8601/1)
        })

      assert_reply(ref, :ok, %{})

      # mate received slots
      assert_push("slots_offer", push)
      assert push == %{"match_id" => match.id, "slots" => slots}
    end
  end

  describe "offer-slots when no match" do
    setup :joined

    setup do
      {:ok, mate: onboarded_user(story: [], location: apple_location(), name: "mate")}
    end

    @tag skip: true
    test "when no match exists", %{socket: socket, mate: mate} do
      Process.flag(:trap_exit, true)
      push(socket, "offer-slots", %{"user_id" => mate.id, "slots" => []})
      assert_receive {:EXIT, _pid, {%Ecto.NoResultsError{}, _stacktrace}}
    end
  end

  describe "offer-slots when invalid slots" do
    setup :joined

    setup %{me: me} do
      mate = onboarded_user(story: [], location: apple_location(), name: "mate")
      match = insert(:match, user_id_1: me.id, user_id_2: mate.id)

      # if it's 14:47 right now, then the slots are
      %DateTime{hour: prev_hour} = dt = DateTime.utc_now() |> DateTime.add(_seconds = -3600)
      date = DateTime.to_date(dt)

      slots =
        [
          # 13:15
          DateTime.new!(date, Time.new!(prev_hour, 15, 0)),
          # 13:30
          DateTime.new!(date, Time.new!(prev_hour, 30, 0)),
          # 13:45
          DateTime.new!(date, Time.new!(prev_hour, 45, 0))
        ]
        |> Enum.map(&DateTime.to_iso8601/1)

      {:ok, mate: mate, match: match, slots: slots}
    end

    test "with match_id", %{slots: slots, match: match, socket: socket} do
      ref = push(socket, "offer-slots", %{"match_id" => match.id, "slots" => []})
      assert_reply(ref, :error, %{slots: ["should have at least 1 item(s)"]})

      ref = push(socket, "offer-slots", %{"match_id" => match.id, "slots" => slots})
      assert_reply(ref, :error, %{slots: ["should have at least 1 item(s)"]})
    end

    test "with user_id", %{slots: slots, mate: mate, socket: socket} do
      ref = push(socket, "offer-slots", %{"user_id" => mate.id, "slots" => []})
      assert_reply(ref, :error, %{slots: ["should have at least 1 item(s)"]})

      ref = push(socket, "offer-slots", %{"user_id" => mate.id, "slots" => slots})
      assert_reply(ref, :error, %{slots: ["should have at least 1 item(s)"]})
    end
  end

  # TODO re-offer when mate offered
  # TODO try to pick slot by mate -> expect error
  describe "pick-slot success" do
    setup :joined

    setup %{me: me} do
      mate = onboarded_user(story: [], location: apple_location(), name: "mate")
      match = insert(:match, user_id_1: me.id, user_id_2: mate.id)
      {:ok, mate: mate, match: match}
    end

    setup :joined_mate

    # mate offers slots to us
    setup %{mate_socket: mate_socket, match: match} do
      # if it's 14:47 right now, then the slots are
      %DateTime{hour: next_hour} = dt = DateTime.utc_now() |> DateTime.add(_seconds = 3600)
      date = DateTime.to_date(dt)

      slots = [
        # 15:15
        DateTime.new!(date, Time.new!(next_hour, 15, 0)),
        # 15:30
        DateTime.new!(date, Time.new!(next_hour, 30, 0)),
        # 15:45
        DateTime.new!(date, Time.new!(next_hour, 45, 0))
      ]

      iso_slots = Enum.map(slots, &DateTime.to_iso8601/1)

      ref = push(mate_socket, "offer-slots", %{"match_id" => match.id, "slots" => iso_slots})
      assert_reply(ref, :ok, _reply)

      # we get slots_offer
      assert_push("slots_offer", push)
      assert push == %{"match_id" => match.id, "slots" => slots}
      refute_receive _anything_else

      {:ok, slots: slots}
    end

    test "with match_id", %{slots: [_s1, s2, _s3] = slots, match: match, socket: socket, me: me} do
      iso_slot = DateTime.to_iso8601(s2)
      ref = push(socket, "pick-slot", %{"match_id" => match.id, "slot" => iso_slot})
      assert_reply(ref, :ok, _reply)

      assert %Timeslot{} = timeslot = Repo.get_by(Timeslot, match_id: match.id)
      assert timeslot.picker_id == me.id
      assert timeslot.slots == slots
      assert timeslot.selected_slot == s2

      # mate gets a slot_accepted notification
      assert_push("slot_accepted", push)
      assert push == %{"match_id" => match.id, "selected_slot" => s2}
    end

    test "with user_id", %{
      slots: [_s1, s2, _s3] = slots,
      match: match,
      mate: mate,
      socket: socket,
      me: me
    } do
      iso_slot = DateTime.to_iso8601(s2)
      ref = push(socket, "pick-slot", %{"user_id" => mate.id, "slot" => iso_slot})
      assert_reply(ref, :ok, _reply)

      assert %Timeslot{} = timeslot = Repo.get_by(Timeslot, match_id: match.id)
      assert timeslot.picker_id == me.id
      assert timeslot.slots == slots
      assert timeslot.selected_slot == s2

      # mate gets a slot_accepted notification
      assert_push("slot_accepted", push)
      assert push == %{"match_id" => match.id, "selected_slot" => s2}
    end

    test "repick", %{slots: [s1, s2, _s3] = slots, match: match, socket: socket, me: me} do
      iso_slot = DateTime.to_iso8601(s2)
      ref = push(socket, "pick-slot", %{"match_id" => match.id, "slot" => iso_slot})
      assert_reply(ref, :ok, _reply)

      # mate first gets second slot
      assert_push("slot_accepted", push)
      assert push == %{"match_id" => match.id, "selected_slot" => s2}

      iso_slot = DateTime.to_iso8601(s1)
      ref = push(socket, "pick-slot", %{"match_id" => match.id, "slot" => iso_slot})
      assert_reply(ref, :ok, _reply)

      # then mate gets first slot
      assert_push("slot_accepted", push)
      assert push == %{"match_id" => match.id, "selected_slot" => s1}

      assert %Timeslot{} = timeslot = Repo.get_by(Timeslot, match_id: match.id)
      assert timeslot.picker_id == me.id
      assert timeslot.slots == slots
      assert timeslot.selected_slot == s1
    end
  end

  # TODO cancel-slot before pick-slot
  describe "cancel-slot after pick-slot success" do
    setup :joined

    setup %{me: me} do
      mate = onboarded_user(story: [], location: apple_location(), name: "mate")
      match = insert(:match, user_id_1: me.id, user_id_2: mate.id)
      {:ok, mate: mate, match: match}
    end

    setup :joined_mate

    # mate offers slots to us, we pick one
    setup %{socket: socket, mate_socket: mate_socket, match: match, mate: mate} do
      # if it's 14:47 right now, then the slots are
      %DateTime{hour: next_hour} = dt = DateTime.utc_now() |> DateTime.add(_seconds = 3600)
      date = DateTime.to_date(dt)

      [_s1, s2, _s3] =
        slots = [
          # 15:15
          DateTime.new!(date, Time.new!(next_hour, 15, 0)),
          # 15:30
          DateTime.new!(date, Time.new!(next_hour, 30, 0)),
          # 15:45
          DateTime.new!(date, Time.new!(next_hour, 45, 0))
        ]

      iso_slots = Enum.map(slots, &DateTime.to_iso8601/1)

      ref = push(mate_socket, "offer-slots", %{"match_id" => match.id, "slots" => iso_slots})
      assert_reply(ref, :ok, _reply)

      # we get slots_offer
      assert_push("slots_offer", push)
      assert push == %{"match_id" => match.id, "slots" => slots}
      refute_receive _anything_else

      # we accept seocnd slot
      iso_slot = DateTime.to_iso8601(s2)
      ref = push(socket, "pick-slot", %{"user_id" => mate.id, "slot" => iso_slot})
      assert_reply(ref, :ok, _reply)

      # mate gets a slot_accepted notification
      assert_push("slot_accepted", push)
      assert push == %{"match_id" => match.id, "selected_slot" => s2}

      {:ok, slots: slots}
    end

    test "with match_id", %{socket: socket, match: match} do
      ref = push(socket, "cancel-slot", %{"match_id" => match.id})
      assert_reply(ref, :ok, _reply)

      # mate gets slot_cancelled notification
      assert_push("slot_cancelled", push)
      assert push == %{"match_id" => match.id}

      # timeslot is reset
      refute Repo.get_by(Timeslot, match_id: match.id)
    end

    test "with user_id", %{socket: socket, match: match, mate: mate} do
      ref = push(socket, "cancel-slot", %{"user_id" => mate.id})
      assert_reply(ref, :ok, _reply)

      # mate gets slot_cancelled notification
      assert_push("slot_cancelled", push)
      assert push == %{"match_id" => match.id}

      # timeslot is reset
      refute Repo.get_by(Timeslot, match_id: match.id)
    end
  end

  describe "unmatch success" do
    setup :joined

    setup do
      {:ok, mate: onboarded_user(story: [], location: apple_location(), name: "mate")}
    end

    setup :joined_mate

    # match
    setup %{me: me, socket: socket, mate: mate, mate_socket: mate_socket} do
      # mate likes us
      ref = push(mate_socket, "like", %{"user_id" => me.id})
      assert_reply(ref, :ok, reply)
      assert reply == %{}

      # now it's our turn
      ref = push(socket, "like", %{"user_id" => mate.id})
      assert_reply(ref, :ok, %{"match_id" => match_id})

      {:ok, match_id: match_id}
    end

    test "with match_id", %{socket: socket, match_id: match_id} do
      ref = push(socket, "unmatch", %{"match_id" => match_id})
      assert_reply(ref, :ok, %{"unmatched?" => true})

      # mate gets unmatched message
      assert_push("unmatched", push)
      assert push == %{"match_id" => match_id}

      refute Repo.get(Match, match_id)
    end

    test "with user_id", %{socket: socket, mate: mate, match_id: match_id} do
      ref = push(socket, "unmatch", %{"user_id" => mate.id})
      assert_reply(ref, :ok, %{"unmatched?" => true})

      # mate gets unmatched message
      assert_push("unmatched", push)
      assert push == %{"match_id" => match_id}

      refute Repo.get(Match, match_id)
    end
  end

  describe "report without match" do
    setup :joined

    setup do
      {:ok, mate: onboarded_user(story: [], location: apple_location(), name: "mate")}
    end

    setup :joined_mate

    test "reports mate", %{socket: socket, mate: mate, me: me} do
      ref =
        push(socket, "report", %{
          "user_id" => mate.id,
          "reason" => "he don't believe in jesus"
        })

      assert_reply(ref, :ok, _reply)
      refute_receive _anything_else

      assert %Accounts.UserReport{} =
               report = Repo.get_by(Accounts.UserReport, from_user_id: me.id, on_user_id: mate.id)

      assert report.reason == "he don't believe in jesus"
    end
  end

  describe "report with match" do
    setup :joined

    setup %{me: me} do
      mate = onboarded_user(story: [], location: apple_location(), name: "mate")
      match = insert(:match, user_id_1: me.id, user_id_2: mate.id)
      {:ok, mate: mate, match: match}
    end

    setup :joined_mate

    test "reports mate and notifies of unmatch", %{
      socket: socket,
      match: match,
      mate: mate,
      me: me
    } do
      ref =
        push(socket, "report", %{
          "user_id" => mate.id,
          "reason" => "he don't believe in jesus"
        })

      assert_reply(ref, :ok, _reply)

      # mate gets unmatch message
      assert_push("unmatched", push)
      assert push == %{"match_id" => match.id}

      assert %Accounts.UserReport{} =
               report = Repo.get_by(Accounts.UserReport, from_user_id: me.id, on_user_id: mate.id)

      assert report.reason == "he don't believe in jesus"
    end
  end

  defp joined(%{socket: socket, me: me}) do
    assert {:ok, _reply, socket} = subscribe_and_join(socket, "feed:" <> me.id)
    {:ok, socket: socket}
  end

  defp activated(%{socket: socket}) do
    ref = push(socket, "activate-session", %{"duration" => 60})
    assert_reply(ref, :ok, _reply)
    :ok
  end

  defp joined_mate(%{mate: mate}) do
    socket = connected_socket(mate)
    {:ok, _reply, socket} = join(socket, "feed:" <> mate.id)
    {:ok, mate_socket: socket}
  end
end
