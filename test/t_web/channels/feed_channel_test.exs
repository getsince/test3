defmodule TWeb.FeedChannelTest do
  use TWeb.ChannelCase

  alias T.{Feeds, Accounts, Calls, Matches}
  alias Matches.{Timeslot, Match}
  alias Feeds.ActiveSession
  alias Calls.Call
  alias Pigeon.APNS.Notification

  import Mox
  setup :verify_on_exit!

  setup do
    me = onboarded_user()
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
          insert(:profile, hidden?: false, story: [], name: "mate-1"),
          insert(:profile, hidden?: false, story: [], name: "mate-2"),
          insert(:profile, hidden?: false, story: [], name: "mate-3")
        ]

      [m1, m2, m3] =
        for mate <- mates do
          insert(:match, user_id_1: me.id, user_id_2: mate.user_id)
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
      insert(:timeslot, match_id: m3.id, slots: slots, selected_slot: s2, picker_id: p3.user_id)
      assert {:ok, reply, _socket} = join(socket, "feed:" <> me.id)

      assert reply == %{
               "matches" => [
                 %{
                   "id" => m1.id,
                   "profile" => %{name: "mate-1", story: [], user_id: p1.user_id}
                 },
                 %{
                   "id" => m2.id,
                   "profile" => %{name: "mate-2", story: [], user_id: p2.user_id},
                   "timeslot" => %{"picker" => me.id, "slots" => slots}
                 },
                 %{
                   "id" => m3.id,
                   "profile" => %{name: "mate-3", story: [], user_id: p3.user_id},
                   "timeslot" => %{"selected_slot" => s2}
                 }
               ]
             }
    end

    test "with invites and current session", %{socket: socket, me: me} do
      mate = insert(:profile, hidden?: false, story: [], name: "mate")

      %ActiveSession{flake: session_id} =
        Feeds.activate_session(me.id, _duration = 60, @reference)

      %ActiveSession{flake: mate_session_id} =
        Feeds.activate_session(mate.user_id, _duration = 60, @reference)

      assert true = Feeds.invite_active_user(mate.user_id, me.id)

      assert {:ok, reply, _socket} = join(socket, "feed:" <> me.id)

      assert reply == %{
               "current_session" => %{id: session_id, expires_at: ~U[2021-07-21 12:55:18Z]},
               "invites" => [
                 %{
                   "profile" => %{name: "mate", story: [], user_id: mate.user_id},
                   "session" => %{id: mate_session_id, expires_at: ~U[2021-07-21 12:55:18Z]}
                 }
               ]
             }
    end

    test "with missed calls", %{socket: socket, me: me} do
      "user_socket:" <> token = socket.id
      mate = insert(:profile, hidden?: false, story: [], name: "mate")

      # activated sessions
      %ActiveSession{flake: session_id} =
        Feeds.activate_session(me.id, _duration = 60, @reference)

      %ActiveSession{flake: mate_session_id} =
        Feeds.activate_session(mate.user_id, _duration = 60, @reference)

      # prepare pushkit devices
      :ok = Accounts.save_pushkit_device_id(me.id, token, Base.decode16!("ABABAB"), env: "prod")

      # prepare apns mock
      expect(MockAPNS, :push, 2, fn [push], :prod -> [%{push | response: :success}] end)

      # mate invites me
      true = Feeds.invite_active_user(me.id, mate.user_id)

      # mate calls me
      {:ok, call_id1} = Calls.call(mate.user_id, me.id)

      # TODO forbid "duplicate" calls?
      {:ok, call_id2} = Calls.call(mate.user_id, me.id)

      refute call_id1 == call_id2

      :ok = Calls.end_call(call_id1)
      %Call{} = c1 = Repo.get(Call, call_id1)
      %Call{} = c2 = Repo.get(Call, call_id2)

      assert {:ok, reply, _socket} = join(socket, "feed:" <> me.id)

      assert reply == %{
               "current_session" => %{expires_at: ~U[2021-07-21 12:55:18Z], id: session_id},
               "missed_calls" => [
                 %{
                   "call" => %{
                     "id" => call_id1,
                     "started_at" => DateTime.from_naive!(c1.inserted_at, "Etc/UTC"),
                     "ended_at" => c1.ended_at
                   },
                   "profile" => %{name: "mate", story: [], user_id: mate.user_id},
                   "session" => %{expires_at: ~U[2021-07-21 12:55:18Z], id: mate_session_id}
                 },
                 %{
                   # TODO call without ended_at should be joined from ios?
                   "call" => %{
                     "id" => call_id2,
                     "started_at" => DateTime.from_naive!(c2.inserted_at, "Etc/UTC")
                   },
                   "profile" => %{name: "mate", story: [], user_id: mate.user_id},
                   "session" => %{expires_at: ~U[2021-07-21 12:55:18Z], id: mate_session_id}
                 }
               ]
             }

      # now with missed_calls_cursor
      assert {:ok, reply, _socket} =
               join(socket, "feed:" <> me.id, %{"missed_calls_cursor" => call_id1})

      assert reply == %{
               "current_session" => %{expires_at: ~U[2021-07-21 12:55:18Z], id: session_id},
               "missed_calls" => [
                 %{
                   "call" => %{
                     "id" => call_id2,
                     "started_at" => DateTime.from_naive!(c2.inserted_at, "Etc/UTC")
                   },
                   "profile" => %{name: "mate", story: [], user_id: mate.user_id},
                   "session" => %{expires_at: ~U[2021-07-21 12:55:18Z], id: mate_session_id}
                 }
               ]
             }
    end
  end

  describe "activate-session" do
    setup :joined

    test "creates new session", %{socket: socket, me: me} do
      ref = push(socket, "activate-session", %{"duration" => _minutes = 60})
      assert_reply ref, :ok
      refute_receive _anything

      assert %ActiveSession{expires_at: expires_at} = Feeds.get_current_session(me.id)
      diff = DateTime.diff(expires_at, DateTime.utc_now())
      assert_in_delta diff, _60_minutes = 3600, 2
    end

    test "prolongs prev session", %{socket: socket, me: me} do
      ref = push(socket, "activate-session", %{"duration" => _minutes = 20})
      assert_reply ref, :ok

      assert %ActiveSession{flake: id, expires_at: expires_at} = Feeds.get_current_session(me.id)
      diff = DateTime.diff(expires_at, DateTime.utc_now())
      assert_in_delta diff, _20_minutes = 1200, 2

      ref = push(socket, "activate-session", %{"duration" => _minutes = 40})
      assert_reply ref, :ok
      refute_receive _anything

      assert %ActiveSession{flake: ^id, expires_at: expires_at} = Feeds.get_current_session(me.id)
      diff = DateTime.diff(expires_at, DateTime.utc_now())
      assert_in_delta diff, _40_minutes = 2400, 2
    end
  end

  describe "deactivate-session" do
    setup :joined

    test "with active session", %{socket: socket} do
      ref = push(socket, "activate-session", %{"duration" => _minutes = 60})
      assert_reply ref, :ok
      refute_receive _anything

      ref = push(socket, "deactivate-session")
      assert_reply ref, :ok, reply
      assert reply == %{"deactivated" => true}
      refute_receive _anything
    end

    test "without active session", %{socket: socket} do
      ref = push(socket, "deactivate-session")
      assert_reply ref, :ok, reply
      assert reply == %{"deactivated" => false}
      refute_receive _anything
    end
  end

  describe "more" do
    setup :joined

    test "with no data in db", %{socket: socket} do
      ref = push(socket, "more")
      assert_reply ref, :ok, reply
      assert reply == %{"cursor" => nil, "feed" => []}
    end

    test "with no active users", %{socket: socket} do
      insert_list(3, :profile)

      ref = push(socket, "more")
      assert_reply ref, :ok, reply
      assert reply == %{"cursor" => nil, "feed" => []}
    end

    test "with active users more than count", %{socket: socket} do
      [p1, p2, p3] =
        others =
        insert_list(3, :profile, story: [%{"background" => %{"s3_key" => "test"}, "labels" => []}])

      [%{flake: s1}, %{flake: s2}, %{flake: s3}] = activate_sessions(others, @reference)

      ref = push(socket, "more", %{"count" => 2})
      assert_reply ref, :ok, %{"cursor" => cursor, "feed" => feed}
      assert is_binary(cursor)

      assert feed == [
               %{
                 "session" => %{
                   id: s1,
                   expires_at: ~U[2021-07-21 12:55:18Z]
                 },
                 "profile" => %{
                   name: nil,
                   story: [
                     %{
                       "background" => %{
                         "proxy" =>
                           "https://d1234.cloudfront.net/1hPLj5rf4QOwpxjzZB_S-X9SsrQMj0cayJcOCmnvXz4/fit/1000/0/sm/0/aHR0cHM6Ly9wcmV0ZW5kLXRoaXMtaXMtcmVhbC5zMy5hbWF6b25hd3MuY29tL3Rlc3Q",
                         "s3_key" => "test"
                       },
                       "labels" => []
                     }
                   ],
                   user_id: p1.user_id
                 }
               },
               %{
                 "session" => %{
                   id: s2,
                   expires_at: ~U[2021-07-21 12:55:18Z]
                 },
                 "profile" => %{
                   name: nil,
                   story: [
                     %{
                       "background" => %{
                         "proxy" =>
                           "https://d1234.cloudfront.net/1hPLj5rf4QOwpxjzZB_S-X9SsrQMj0cayJcOCmnvXz4/fit/1000/0/sm/0/aHR0cHM6Ly9wcmV0ZW5kLXRoaXMtaXMtcmVhbC5zMy5hbWF6b25hd3MuY29tL3Rlc3Q",
                         "s3_key" => "test"
                       },
                       "labels" => []
                     }
                   ],
                   user_id: p2.user_id
                 }
               }
             ]

      ref = push(socket, "more", %{"cursor" => cursor})

      assert_reply ref, :ok, %{
        "cursor" => cursor,
        "feed" => feed
      }

      assert feed == [
               %{
                 "session" => %{
                   id: s3,
                   expires_at: ~U[2021-07-21 12:55:18Z]
                 },
                 "profile" => %{
                   name: nil,
                   story: [
                     %{
                       "background" => %{
                         "proxy" =>
                           "https://d1234.cloudfront.net/1hPLj5rf4QOwpxjzZB_S-X9SsrQMj0cayJcOCmnvXz4/fit/1000/0/sm/0/aHR0cHM6Ly9wcmV0ZW5kLXRoaXMtaXMtcmVhbC5zMy5hbWF6b25hd3MuY29tL3Rlc3Q",
                         "s3_key" => "test"
                       },
                       "labels" => []
                     }
                   ],
                   user_id: p3.user_id
                 }
               }
             ]

      ref = push(socket, "more", %{"cursor" => cursor})
      assert_reply ref, :ok, %{"cursor" => ^cursor, "feed" => []}
    end
  end

  describe "invite" do
    setup :joined

    test "invited by active user", %{me: me, socket: socket} do
      %{flake: s1} = activate_session(me, @reference)

      other = onboarded_user()
      %{flake: s2} = activate_session(other, @reference)

      spawn(fn ->
        socket = connected_socket(other)
        {:ok, _reply, socket} = subscribe_and_join(socket, "feed:" <> other.id)
        ref = push(socket, "invite", %{"user_id" => me.id})
        assert_reply ref, :ok, reply
        assert reply == %{"invited" => true}
      end)

      assert_push "activated", push

      assert push == %{
               "session" => %{
                 id: s1,
                 expires_at: ~U[2021-07-21 12:55:18Z]
               },
               "profile" => %{
                 name: "that",
                 story: [
                   %{
                     "background" => %{
                       "proxy" =>
                         "https://d1234.cloudfront.net/e9a8Yq80qbgr7QH43crdCBPWdt6OACyhD5xWN8ysFok/fit/1000/0/sm/0/aHR0cHM6Ly9wcmV0ZW5kLXRoaXMtaXMtcmVhbC5zMy5hbWF6b25hd3MuY29tL3Bob3RvLmpwZw",
                       "s3_key" => "photo.jpg"
                     },
                     "labels" => [
                       %{
                         "dimensions" => [400, 800],
                         "position" => 'dd',
                         "rotation" => 21,
                         "type" => "text",
                         "value" => "just some text",
                         "zoom" => 1.2
                       },
                       %{
                         "answer" => "msu",
                         "dimensions" => [400, 800],
                         "position" => [150, 150],
                         "question" => "university",
                         "type" => "answer",
                         "value" => "🥊\nменя воспитала улица"
                       }
                     ]
                   }
                 ],
                 user_id: me.id
               }
             }

      assert_push "activated", push

      assert push == %{
               "session" => %{
                 id: s2,
                 expires_at: ~U[2021-07-21 12:55:18Z]
               },
               "profile" => %{
                 name: "that",
                 story: [
                   %{
                     "background" => %{
                       "proxy" =>
                         "https://d1234.cloudfront.net/e9a8Yq80qbgr7QH43crdCBPWdt6OACyhD5xWN8ysFok/fit/1000/0/sm/0/aHR0cHM6Ly9wcmV0ZW5kLXRoaXMtaXMtcmVhbC5zMy5hbWF6b25hd3MuY29tL3Bob3RvLmpwZw",
                       "s3_key" => "photo.jpg"
                     },
                     "labels" => [
                       %{
                         "dimensions" => [400, 800],
                         "position" => 'dd',
                         "rotation" => 21,
                         "type" => "text",
                         "value" => "just some text",
                         "zoom" => 1.2
                       },
                       %{
                         "answer" => "msu",
                         "dimensions" => [400, 800],
                         "position" => [150, 150],
                         "question" => "university",
                         "type" => "answer",
                         "value" => "🥊\nменя воспитала улица"
                       }
                     ]
                   }
                 ],
                 user_id: other.id
               }
             }

      assert_push "invite", push

      assert push == %{
               "session" => %{
                 id: s2,
                 expires_at: ~U[2021-07-21 12:55:18Z]
               },
               "profile" => %{
                 name: "that",
                 story: [
                   %{
                     "background" => %{
                       "proxy" =>
                         "https://d1234.cloudfront.net/e9a8Yq80qbgr7QH43crdCBPWdt6OACyhD5xWN8ysFok/fit/1000/0/sm/0/aHR0cHM6Ly9wcmV0ZW5kLXRoaXMtaXMtcmVhbC5zMy5hbWF6b25hd3MuY29tL3Bob3RvLmpwZw",
                       "s3_key" => "photo.jpg"
                     },
                     "labels" => [
                       %{
                         "dimensions" => [400, 800],
                         "position" => 'dd',
                         "rotation" => 21,
                         "type" => "text",
                         "value" => "just some text",
                         "zoom" => 1.2
                       },
                       %{
                         "answer" => "msu",
                         "dimensions" => [400, 800],
                         "position" => [150, 150],
                         "question" => "university",
                         "type" => "answer",
                         "value" => "🥊\nменя воспитала улица"
                       }
                     ]
                   }
                 ],
                 user_id: other.id
               }
             }

      refute_receive _anything_else

      ref = push(socket, "invites")
      assert_reply ref, :ok, reply

      assert reply == %{
               "invites" => [
                 %{
                   "session" => %{
                     id: s2,
                     expires_at: ~U[2021-07-21 12:55:18Z]
                   },
                   "profile" => %{
                     name: "that",
                     story: [
                       %{
                         "background" => %{
                           "proxy" =>
                             "https://d1234.cloudfront.net/e9a8Yq80qbgr7QH43crdCBPWdt6OACyhD5xWN8ysFok/fit/1000/0/sm/0/aHR0cHM6Ly9wcmV0ZW5kLXRoaXMtaXMtcmVhbC5zMy5hbWF6b25hd3MuY29tL3Bob3RvLmpwZw",
                           "s3_key" => "photo.jpg"
                         },
                         "labels" => [
                           %{
                             "dimensions" => [400, 800],
                             "position" => 'dd',
                             "rotation" => 21,
                             "type" => "text",
                             "value" => "just some text",
                             "zoom" => 1.2
                           },
                           %{
                             "answer" => "msu",
                             "dimensions" => [400, 800],
                             "position" => [150, 150],
                             "question" => "university",
                             "type" => "answer",
                             "value" => "🥊\nменя воспитала улица"
                           }
                         ]
                       }
                     ],
                     user_id: other.id
                   }
                 }
               ]
             }
    end
  end

  describe "call without mate's active session" do
    setup [:joined, :activated]

    setup do
      {:ok, mate: insert(:profile, story: [], hidden?: false)}
    end

    # mate doesn't have an active session, so they can't be called
    test "is not allowed", %{socket: socket, mate: mate} do
      ref = push(socket, "call", %{"user_id" => mate.user_id})
      assert_reply ref, :error, reply
      assert reply == %{"reason" => "call not allowed"}
    end
  end

  describe "failed calls to active mate" do
    setup [:joined, :activated]

    setup do
      {:ok, mate: insert(:profile, story: [], hidden?: false)}
    end

    setup :activated_mate

    test "missing invite", %{socket: socket, mate: mate} do
      ref = push(socket, "call", %{"user_id" => mate.user_id})
      assert_reply ref, :error, reply
      assert reply == %{"reason" => "call not allowed"}
    end

    test "missing pushkit devices", %{
      me: me,
      socket: socket,
      mate: mate,
      mate_socket: mate_socket
    } do
      # mate invites us
      ref = push(mate_socket, "invite", %{"user_id" => me.id})
      assert_reply ref, :ok, reply
      assert reply == %{"invited" => true}

      # current user receives invite
      assert_push "invite", %{
        "profile" => profile,
        "session" => %{expires_at: %DateTime{}, id: _session_id}
      }

      assert profile == %{name: nil, story: [], user_id: mate.user_id}
      refute_receive _anything_else

      # call still fails since mate is missing pushkit devices
      ref = push(socket, "call", %{"user_id" => mate.user_id})
      assert_reply ref, :error, reply
      assert reply == %{"reason" => "no pushkit devices available"}
    end

    test "failed apns request", %{
      me: me,
      socket: socket,
      mate: mate,
      mate_socket: mate_socket
    } do
      "user_socket:" <> mate_token = mate_socket.id
      # store some apns devices for mate
      :ok =
        Accounts.save_pushkit_device_id(
          mate.user_id,
          mate_token,
          Base.decode16!("ABABABAB"),
          env: "prod"
        )

      :ok =
        Accounts.save_pushkit_device_id(
          mate.user_id,
          mate.user
          |> Accounts.generate_user_session_token("mobile")
          |> Accounts.UserToken.encoded_token(),
          Base.decode16!("BABABABABA"),
          env: "sandbox"
        )

      # mate invites us
      ref = push(mate_socket, "invite", %{"user_id" => me.id})
      assert_reply ref, :ok, _reply

      # current user receives invite
      assert_push "invite", _push

      MockAPNS
      # ABABABAB on prod -> fails!
      |> expect(:push, fn [%Notification{} = n], :prod ->
        assert n.device_token == "ABABABAB"
        assert n.topic == "app.topic.voip"
        assert n.push_type == "voip"
        assert n.expiration == 0
        assert n.payload["caller_id"] == me.id
        assert n.payload["caller_name"] == "that"
        assert n.payload["call_id"]
        [%Notification{n | response: :bad_device_token}]
      end)
      # BABABABABA on sandbox -> fails!
      |> expect(:push, fn [%Notification{} = n], :dev ->
        assert n.device_token == "BABABABABA"
        assert n.topic == "app.topic.voip"
        assert n.push_type == "voip"
        assert n.expiration == 0
        assert n.payload["caller_id"] == me.id
        assert n.payload["caller_name"] == "that"
        assert n.payload["call_id"]
        [%Notification{n | response: :bad_device_token}]
      end)

      # call still can fail if apns requests fail
      ref = push(socket, "call", %{"user_id" => mate.user_id})
      assert_reply ref, :error, reply
      assert reply == %{"reason" => "all pushes failed"}
    end
  end

  describe "successful calls to active mate" do
    setup [:joined, :activated]

    setup do
      {:ok, mate: insert(:profile, story: [], hidden?: false)}
    end

    setup :activated_mate

    setup %{mate: mate, mate_socket: mate_socket} do
      "user_socket:" <> mate_token = mate_socket.id

      :ok =
        Accounts.save_pushkit_device_id(
          mate.user_id,
          mate_token,
          Base.decode16!("ABABABAB"),
          env: "prod"
        )

      :ok =
        Accounts.save_pushkit_device_id(
          mate.user_id,
          mate.user
          |> Accounts.generate_user_session_token("mobile")
          |> Accounts.UserToken.encoded_token(),
          Base.decode16!("BABABABABA"),
          env: "sandbox"
        )
    end

    test "when invited by mate", %{
      me: me,
      socket: socket,
      mate: mate,
      mate_socket: mate_socket
    } do
      # mate invites us
      ref = push(mate_socket, "invite", %{"user_id" => me.id})
      assert_reply ref, :ok, _reply

      # current user receives invite
      assert_push "invite", _push

      MockAPNS
      # ABABABAB on prod -> fails!
      |> expect(:push, fn [%Notification{} = n], :prod ->
        [%Notification{n | response: :bad_device_token}]
      end)
      # BABABABABA on sandbox -> success!
      |> expect(:push, fn [%Notification{} = n], :dev ->
        [%Notification{n | response: :success}]
      end)

      # call succeeds
      ref = push(socket, "call", %{"user_id" => mate.user_id})
      assert_reply ref, :ok, %{"call_id" => call_id}

      assert %Call{id: ^call_id} = call = Repo.get!(Calls.Call, call_id)

      refute call.ended_at
      refute call.accepted_at
      assert call.caller_id == me.id
      assert call.called_id == mate.user_id
    end

    test "when missed mate's call", %{
      me: me,
      socket: socket,
      mate: mate,
      mate_socket: mate_socket
    } do
      # now we also need a pushkit device
      "user_socket:" <> my_token = socket.id

      :ok =
        Accounts.save_pushkit_device_id(
          me.id,
          my_token,
          Base.decode16!("ABCBABCA"),
          env: "prod"
        )

      # we invite mate
      ref = push(socket, "invite", %{"user_id" => mate.user_id})
      assert_reply ref, :ok, _reply

      # ABCBABCA on prod -> success
      expect(MockAPNS, :push, fn [%Notification{} = n], :prod ->
        [%Notification{n | response: :success}]
      end)

      # mate calls us
      ref = push(mate_socket, "call", %{"user_id" => me.id})
      assert_reply ref, :ok, %{"call_id" => call_id}

      # mate joins call channel and waits
      {:ok, reply, mate_socket} = join(mate_socket, "call:" <> call_id)

      assert reply == %{
               ice_servers: [
                 %{
                   "url" => "stun:global.stun.twilio.com:3478?transport=udp",
                   "urls" => "stun:global.stun.twilio.com:3478?transport=udp"
                 },
                 %{
                   "credential" => "B2AhKtD3x/T0vATYL2FimHFlPMTIJAmAmHBRrqAHEKc=",
                   "url" => "turn:global.turn.twilio.com:3478?transport=udp",
                   "urls" => "turn:global.turn.twilio.com:3478?transport=udp",
                   "username" =>
                     "65d32d2326762b02b0133dadd624f74333dea32e5588ef495986d9b5e4b932d3"
                 },
                 %{
                   "credential" => "B2AhKtD3x/T0vATYL2FimHFlPMTIJAmAmHBRrqAHEKc=",
                   "url" => "turn:global.turn.twilio.com:3478?transport=tcp",
                   "urls" => "turn:global.turn.twilio.com:3478?transport=tcp",
                   "username" =>
                     "65d32d2326762b02b0133dadd624f74333dea32e5588ef495986d9b5e4b932d3"
                 },
                 %{
                   "credential" => "B2AhKtD3x/T0vATYL2FimHFlPMTIJAmAmHBRrqAHEKc=",
                   "url" => "turn:global.turn.twilio.com:443?transport=tcp",
                   "urls" => "turn:global.turn.twilio.com:443?transport=tcp",
                   "username" =>
                     "65d32d2326762b02b0133dadd624f74333dea32e5588ef495986d9b5e4b932d3"
                 }
               ]
             }

      # and then hangs up
      ref = push(mate_socket, "hang-up")
      assert_reply ref, :ok, _reply

      # we missed the call but we can call now

      # these are the pushes sent to mate
      MockAPNS
      # ABABABAB on prod -> fails!
      |> expect(:push, fn [%Notification{} = n], :prod ->
        [%Notification{n | response: :bad_device_token}]
      end)
      # BABABABABA on sandbox -> success!
      |> expect(:push, fn [%Notification{} = n], :dev ->
        [%Notification{n | response: :success}]
      end)

      # call succeeds
      ref = push(socket, "call", %{"user_id" => mate.user_id})
      assert_reply ref, :ok, %{"call_id" => call_id2}

      # it's a new call
      refute call_id2 == call_id
    end

    test "when matched with mate", %{me: me, mate: mate, socket: socket} do
      insert(:match, user_id_1: me.id, user_id_2: mate.user_id)

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

      ref = push(socket, "call", %{"user_id" => mate.user_id})
      assert_reply ref, :ok, %{"call_id" => call_id}

      assert %Call{id: ^call_id} = call = Repo.get!(Calls.Call, call_id)

      refute call.ended_at
      refute call.accepted_at
      assert call.caller_id == me.id
      assert call.called_id == mate.user_id
    end
  end

  describe "like" do
    setup :joined

    setup do
      {:ok, mate: insert(:profile, story: [], hidden?: false)}
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
      assert_reply ref, :ok, reply
      assert reply == %{}

      # now it's our turn
      ref = push(socket, "like", %{"user_id" => mate.user_id})
      assert_reply ref, :ok, %{"match_id" => match_id}
      assert is_binary(match_id)
    end

    test "when not yet liked by mate", %{
      me: me,
      socket: socket,
      mate: mate,
      mate_socket: mate_socket
    } do
      # we like mate
      ref = push(socket, "like", %{"user_id" => mate.user_id})
      assert_reply ref, :ok, reply
      assert reply == %{}

      # now mate likes us
      ref = push(mate_socket, "like", %{"user_id" => me.id})
      assert_reply ref, :ok, %{"match_id" => match_id}
      assert is_binary(match_id)

      assert_push "matched", push

      assert push == %{
               "match" => %{
                 "id" => match_id,
                 "profile" => %{name: nil, story: [], user_id: mate.user_id}
               }
             }
    end
  end

  # TODO re-offer
  describe "offer-slots success" do
    setup :joined

    setup %{me: me} do
      mate = insert(:profile, story: [], hidden?: false)
      match = insert(:match, user_id_1: me.id, user_id_2: mate.user_id)

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

      assert_reply ref, :ok, %{}

      # mate received slots
      assert_push "slots_offer", push
      assert push == %{"match_id" => match.id, "slots" => slots}
    end

    test "with user_id", %{slots: slots, mate: mate, match: match, socket: socket} do
      ref =
        push(socket, "offer-slots", %{
          "user_id" => mate.user_id,
          "slots" => Enum.map(slots, &DateTime.to_iso8601/1)
        })

      assert_reply ref, :ok, %{}

      # mate received slots
      assert_push "slots_offer", push
      assert push == %{"match_id" => match.id, "slots" => slots}
    end
  end

  describe "offer-slots when no match" do
    setup :joined

    setup do
      {:ok, mate: insert(:profile, story: [], hidden?: false)}
    end

    @tag skip: true
    test "when no match exists", %{socket: socket, mate: mate} do
      Process.flag(:trap_exit, true)
      push(socket, "offer-slots", %{"user_id" => mate.user_id, "slots" => []})
      assert_receive {:EXIT, _pid, {%Ecto.NoResultsError{}, _stacktrace}}
    end
  end

  describe "offer-slots when invalid slots" do
    setup :joined

    setup %{me: me} do
      mate = insert(:profile, story: [], hidden?: false)
      match = insert(:match, user_id_1: me.id, user_id_2: mate.user_id)

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
      assert_reply ref, :error, %{slots: ["should have at least 1 item(s)"]}

      ref = push(socket, "offer-slots", %{"match_id" => match.id, "slots" => slots})
      assert_reply ref, :error, %{slots: ["should have at least 1 item(s)"]}
    end

    test "with user_id", %{slots: slots, mate: mate, socket: socket} do
      ref = push(socket, "offer-slots", %{"user_id" => mate.user_id, "slots" => []})
      assert_reply ref, :error, %{slots: ["should have at least 1 item(s)"]}

      ref = push(socket, "offer-slots", %{"user_id" => mate.user_id, "slots" => slots})
      assert_reply ref, :error, %{slots: ["should have at least 1 item(s)"]}
    end
  end

  # TODO re-offer when mate offered
  # TODO try to pick slot by mate -> expect error
  describe "pick-slot success" do
    setup :joined

    setup %{me: me} do
      mate = insert(:profile, story: [], hidden?: false)
      match = insert(:match, user_id_1: me.id, user_id_2: mate.user_id)
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
      assert_reply ref, :ok, _reply

      # we get slots_offer
      assert_push "slots_offer", push
      assert push == %{"match_id" => match.id, "slots" => slots}
      refute_receive _anything_else

      {:ok, slots: slots}
    end

    test "with match_id", %{slots: [_s1, s2, _s3] = slots, match: match, socket: socket, me: me} do
      iso_slot = DateTime.to_iso8601(s2)
      ref = push(socket, "pick-slot", %{"match_id" => match.id, "slot" => iso_slot})
      assert_reply ref, :ok, _reply

      assert %Timeslot{} = timeslot = Repo.get_by(Timeslot, match_id: match.id)
      assert timeslot.picker_id == me.id
      assert timeslot.slots == slots
      assert timeslot.selected_slot == s2

      # mate gets a slot_accepted notification
      assert_push "slot_accepted", push
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
      ref = push(socket, "pick-slot", %{"user_id" => mate.user_id, "slot" => iso_slot})
      assert_reply ref, :ok, _reply

      assert %Timeslot{} = timeslot = Repo.get_by(Timeslot, match_id: match.id)
      assert timeslot.picker_id == me.id
      assert timeslot.slots == slots
      assert timeslot.selected_slot == s2

      # mate gets a slot_accepted notification
      assert_push "slot_accepted", push
      assert push == %{"match_id" => match.id, "selected_slot" => s2}
    end

    test "repick", %{slots: [s1, s2, _s3] = slots, match: match, socket: socket, me: me} do
      iso_slot = DateTime.to_iso8601(s2)
      ref = push(socket, "pick-slot", %{"match_id" => match.id, "slot" => iso_slot})
      assert_reply ref, :ok, _reply

      # mate first gets second slot
      assert_push "slot_accepted", push
      assert push == %{"match_id" => match.id, "selected_slot" => s2}

      iso_slot = DateTime.to_iso8601(s1)
      ref = push(socket, "pick-slot", %{"match_id" => match.id, "slot" => iso_slot})
      assert_reply ref, :ok, _reply

      # then mate gets first slot
      assert_push "slot_accepted", push
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
      mate = insert(:profile, story: [], hidden?: false)
      match = insert(:match, user_id_1: me.id, user_id_2: mate.user_id)
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
      assert_reply ref, :ok, _reply

      # we get slots_offer
      assert_push "slots_offer", push
      assert push == %{"match_id" => match.id, "slots" => slots}
      refute_receive _anything_else

      # we accept seocnd slot
      iso_slot = DateTime.to_iso8601(s2)
      ref = push(socket, "pick-slot", %{"user_id" => mate.user_id, "slot" => iso_slot})
      assert_reply ref, :ok, _reply

      # mate gets a slot_accepted notification
      assert_push "slot_accepted", push
      assert push == %{"match_id" => match.id, "selected_slot" => s2}

      {:ok, slots: slots}
    end

    test "with match_id", %{socket: socket, match: match} do
      ref = push(socket, "cancel-slot", %{"match_id" => match.id})
      assert_reply ref, :ok, _reply

      # mate gets slot_cancelled notification
      assert_push "slot_cancelled", push
      assert push == %{"match_id" => match.id}

      # timeslot is reset
      refute Repo.get_by(Timeslot, match_id: match.id)
    end

    test "with user_id", %{socket: socket, match: match, mate: mate} do
      ref = push(socket, "cancel-slot", %{"user_id" => mate.user_id})
      assert_reply ref, :ok, _reply

      # mate gets slot_cancelled notification
      assert_push "slot_cancelled", push
      assert push == %{"match_id" => match.id}

      # timeslot is reset
      refute Repo.get_by(Timeslot, match_id: match.id)
    end
  end

  describe "unmatch success" do
    setup :joined

    setup do
      {:ok, mate: insert(:profile, story: [], hidden?: false)}
    end

    setup :joined_mate

    # match
    setup %{me: me, socket: socket, mate: mate, mate_socket: mate_socket} do
      # mate likes us
      ref = push(mate_socket, "like", %{"user_id" => me.id})
      assert_reply ref, :ok, reply
      assert reply == %{}

      # now it's our turn
      ref = push(socket, "like", %{"user_id" => mate.user_id})
      assert_reply ref, :ok, %{"match_id" => match_id}

      {:ok, match_id: match_id}
    end

    test "with match_id", %{socket: socket, match_id: match_id} do
      ref = push(socket, "unmatch", %{"match_id" => match_id})
      assert_reply ref, :ok, %{"unmatched?" => true}

      # mate gets unmatched message
      assert_push "unmatched", push
      assert push == %{"match_id" => match_id}

      refute Repo.get(Match, match_id)
    end

    test "with user_id", %{socket: socket, mate: mate, match_id: match_id} do
      ref = push(socket, "unmatch", %{"user_id" => mate.user_id})
      assert_reply ref, :ok, %{"unmatched?" => true}

      # mate gets unmatched message
      assert_push "unmatched", push
      assert push == %{"match_id" => match_id}

      refute Repo.get(Match, match_id)
    end
  end

  describe "report without match" do
    setup :joined

    setup do
      {:ok, mate: insert(:profile, story: [], hidden?: false)}
    end

    setup :joined_mate

    test "reports mate", %{socket: socket, mate: mate, me: me} do
      ref =
        push(socket, "report", %{
          "user_id" => mate.user_id,
          "reason" => "he don't believe in jesus"
        })

      assert_reply ref, :ok, _reply
      refute_receive _anything_else

      assert %Accounts.UserReport{} =
               report =
               Repo.get_by(Accounts.UserReport, from_user_id: me.id, on_user_id: mate.user_id)

      assert report.reason == "he don't believe in jesus"
    end
  end

  describe "report with match" do
    setup :joined

    setup %{me: me} do
      mate = insert(:profile, story: [], hidden?: false)
      match = insert(:match, user_id_1: me.id, user_id_2: mate.user_id)
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
          "user_id" => mate.user_id,
          "reason" => "he don't believe in jesus"
        })

      assert_reply ref, :ok, _reply

      # mate gets unmatch message
      assert_push "unmatched", push
      assert push == %{"match_id" => match.id}

      assert %Accounts.UserReport{} =
               report =
               Repo.get_by(Accounts.UserReport, from_user_id: me.id, on_user_id: mate.user_id)

      assert report.reason == "he don't believe in jesus"
    end
  end

  defp joined(%{socket: socket, me: me}) do
    assert {:ok, _reply, socket} = subscribe_and_join(socket, "feed:" <> me.id)
    {:ok, socket: socket}
  end

  defp activated(%{socket: socket}) do
    ref = push(socket, "activate-session", %{"duration" => 60})
    assert_reply ref, :ok, _reply
    :ok
  end

  defp joined_mate(%{mate: mate}) do
    socket = connected_socket(mate.user)
    {:ok, _reply, socket} = join(socket, "feed:" <> mate.user_id)
    {:ok, mate_socket: socket}
  end

  defp activated_mate(%{mate: mate}) do
    socket = connected_socket(mate.user)
    {:ok, reply, socket} = join(socket, "feed:" <> mate.user_id)

    # mate has no active session, so needs to activate one
    assert reply == %{}

    ref = push(socket, "activate-session", %{"duration" => _minutes = 60})
    assert_reply ref, :ok, _reply

    # our user receives "activated" event
    assert_push "activated", %{
      "profile" => profile,
      "session" => %{expires_at: %DateTime{}, id: _session_id}
    }

    assert profile == %{name: nil, story: [], user_id: mate.user_id}
    refute_receive _anything_else

    {:ok, mate_socket: socket}
  end
end
