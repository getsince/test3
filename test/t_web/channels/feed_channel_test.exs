defmodule TWeb.FeedChannelTest do
  use TWeb.ChannelCase, async: true

  alias T.{Accounts, Calls, Matches, Feeds}
  alias Matches.{Timeslot, Match, MatchEvent}
  alias Calls.Call

  import Mox
  setup :verify_on_exit!

  setup do
    me = onboarded_user(location: moscow_location(), accept_genders: ["F", "N", "M"])
    {:ok, me: me, socket: connected_socket(me)}
  end

  describe "join" do
    test "with invalid topic", %{socket: socket} do
      assert {:error, %{"error" => "forbidden"}} = join(socket, "feed:" <> Ecto.UUID.generate())
    end

    test "with matches", %{socket: socket, me: me} do
      [p1, p2, p3, p4, p5, p6] = [
        onboarded_user(story: [], name: "mate-1", location: apple_location(), gender: "F"),
        onboarded_user(story: [], name: "mate-2", location: apple_location(), gender: "N"),
        onboarded_user(story: [], name: "mate-3", location: apple_location(), gender: "M"),
        onboarded_user(story: [], name: "mate-4", location: apple_location(), gender: "F"),
        onboarded_user(story: [], name: "mate-5", location: apple_location(), gender: "F"),
        onboarded_user(story: [], name: "mate-6", location: apple_location(), gender: "F")
      ]

      [m1, m2, m3, m4, m5, m6] = [
        insert(:match, user_id_1: me.id, user_id_2: p1.id, inserted_at: ~N[2021-09-30 12:16:05]),
        insert(:match, user_id_1: me.id, user_id_2: p2.id, inserted_at: ~N[2021-09-30 12:16:06]),
        insert(:match, user_id_1: me.id, user_id_2: p3.id, inserted_at: ~N[2021-09-30 12:16:07]),
        insert(:match, user_id_1: me.id, user_id_2: p4.id, inserted_at: ~N[2021-09-30 12:16:08]),
        insert(:match, user_id_1: me.id, user_id_2: p5.id, inserted_at: ~N[2021-09-30 12:16:09]),
        insert(:match, user_id_1: me.id, user_id_2: p6.id, inserted_at: ~N[2021-09-30 12:16:10])
      ]

      now = ~U[2021-09-30 14:47:00.123456Z]

      slots = [
        ~U[2021-09-30 15:15:00Z],
        s2 = ~U[2021-09-30 15:30:00Z],
        ~U[2021-09-30 15:45:00Z]
      ]

      raw_slots = Enum.map(slots, &DateTime.to_iso8601/1)

      # first match is in contacts exchange interaction mode
      Matches.save_contacts_offer_for_match(
        me.id,
        m1.id,
        _contacts = %{"telegram" => "@abcde"},
        now
      )

      # second match starts off as timeslots exchange
      Matches.save_slots_offer_for_match(p2.id, m2.id, raw_slots, now)
      # and then sends contacts as well
      Matches.save_contacts_offer_for_match(
        me.id,
        m2.id,
        _contacts = %{"whatsapp" => "+79666666666"},
        now
      )

      # third match is in timeslots exchange interaction mode
      Matches.save_slots_offer_for_match(me.id, m3.id, raw_slots, now)
      Matches.accept_slot_for_match(p3.id, m3.id, DateTime.to_iso8601(s2), now)

      # fourth match doesn't have any interaction
      # ¯\_ (ツ)_/¯

      # fifth match has some voicemail
      # these messages will be overwritten by ...
      Calls.voicemail_save_message(me.id, m5.id, _s3_key = "0b1124d1-9064-4077-9094-48ade2a90267")
      Calls.voicemail_save_message(me.id, m5.id, _s3_key = "2ba1da54-d873-4ab7-a66b-8359e073dbc0")
      # ... message from mate
      Calls.voicemail_save_message(p5.id, m5.id, _s3_key = "23f442c7-e610-4aa9-ad4c-7795bb568c4e")

      # sixth match has listened voicemail
      {:ok, listened_voicemail} =
        Calls.voicemail_save_message(
          p6.id,
          m6.id,
          _s3_key = "74a1b6d5-9b1d-43ff-bd11-9f17533f40f0"
        )

      assert Calls.voicemail_listen_message(me.id, listened_voicemail.id, now)

      assert {:ok, %{"matches" => matches}, _socket} =
               join(socket, "feed:" <> me.id, %{"mode" => "normal"})

      %{"voicemail" => voicemail_m6} = Enum.at(matches, 0)
      %{id: p6_id} = p6

      assert %{
               "caller_id" => ^p6_id,
               "messages" => [
                 %{
                   id: _,
                   inserted_at: _,
                   listened_at: ~U[2021-09-30 14:47:00Z],
                   s3_key: "74a1b6d5-9b1d-43ff-bd11-9f17533f40f0",
                   url: _
                 }
               ]
             } = voicemail_m6

      %{"voicemail" => voicemail_m5} = Enum.at(matches, 1)
      %{id: p5_id} = p5

      assert %{
               "caller_id" => ^p5_id,
               "messages" => [
                 %{
                   id: _,
                   inserted_at: _,
                   s3_key: "23f442c7-e610-4aa9-ad4c-7795bb568c4e",
                   url: _
                 }
               ]
             } = voicemail_m5

      assert matches == [
               %{
                 "id" => m6.id,
                 "profile" => %{name: "mate-6", story: [], user_id: p6.id, gender: "F"},
                 "audio_only" => false,
                 "voicemail" => voicemail_m6,
                 "expiration_date" => ~U[2021-10-07 12:16:10Z],
                 "inserted_at" => ~U[2021-09-30 12:16:10Z]
               },
               %{
                 "id" => m5.id,
                 "profile" => %{name: "mate-5", story: [], user_id: p5.id, gender: "F"},
                 "audio_only" => false,
                 "voicemail" => voicemail_m5,
                 "expiration_date" => ~U[2021-10-07 12:16:09Z],
                 "inserted_at" => ~U[2021-09-30 12:16:09Z]
               },
               %{
                 "id" => m4.id,
                 "profile" => %{name: "mate-4", story: [], user_id: p4.id, gender: "F"},
                 "audio_only" => false,
                 "expiration_date" => ~U[2021-10-07 12:16:08Z],
                 "inserted_at" => ~U[2021-09-30 12:16:08Z]
               },
               %{
                 "id" => m3.id,
                 "profile" => %{name: "mate-3", story: [], user_id: p3.id, gender: "M"},
                 "timeslot" => %{
                   "selected_slot" => s2,
                   "accepted_at" => ~U[2021-09-30 14:47:00Z],
                   "inserted_at" => ~U[2021-09-30 14:47:00Z]
                 },
                 "audio_only" => false,
                 "expiration_date" => ~U[2021-10-07 12:16:07Z],
                 "inserted_at" => ~U[2021-09-30 12:16:07Z]
               },
               %{
                 "id" => m2.id,
                 "profile" => %{name: "mate-2", story: [], user_id: p2.id, gender: "N"},
                 "timeslot" => %{
                   "picker" => me.id,
                   "slots" => [
                     ~U[2021-09-30 15:15:00Z],
                     ~U[2021-09-30 15:30:00Z],
                     ~U[2021-09-30 15:45:00Z]
                   ],
                   "inserted_at" => ~U[2021-09-30 14:47:00Z]
                 },
                 "contact" => %{
                   "contacts" => %{"whatsapp" => "+79666666666"},
                   "inserted_at" => ~U[2021-09-30 14:47:00Z],
                   "opened_contact_type" => nil,
                   "picker" => p2.id
                 },
                 "audio_only" => false,
                 "expiration_date" => ~U[2021-10-07 12:16:06Z],
                 "inserted_at" => ~U[2021-09-30 12:16:06Z]
               },
               %{
                 "id" => m1.id,
                 "profile" => %{name: "mate-1", story: [], user_id: p1.id, gender: "F"},
                 "contact" => %{
                   "contacts" => %{"telegram" => "@abcde"},
                   "picker" => p1.id,
                   "opened_contact_type" => nil,
                   "inserted_at" => ~U[2021-09-30 14:47:00Z]
                 },
                 "audio_only" => false,
                 "expiration_date" => ~U[2021-10-07 12:16:05Z],
                 "inserted_at" => ~U[2021-09-30 12:16:05Z]
               }
             ]
    end

    test "with archive match", %{socket: socket, me: me} do
      p1 = onboarded_user(story: [], name: "mate-1", location: apple_location(), gender: "F")

      m1 =
        insert(:match, user_id_1: me.id, user_id_2: p1.id, inserted_at: ~N[2021-09-30 12:16:05])

      expiration_date =
        m1.inserted_at
        |> DateTime.from_naive!("Etc/UTC")
        |> DateTime.add(Matches.match_ttl())

      assert {:ok, %{"matches" => matches}, socket} =
               join(socket, "feed:" <> me.id, %{"mode" => "normal"})

      assert matches == [
               %{
                 "id" => m1.id,
                 "profile" => %{name: "mate-1", story: [], user_id: p1.id, gender: "F"},
                 "audio_only" => false,
                 "expiration_date" => expiration_date,
                 "inserted_at" => ~U[2021-09-30 12:16:05Z]
               }
             ]

      push(socket, "archive-match", %{"match_id" => m1.id})

      assert {:ok, reply, socket} = join(socket, "feed:" <> me.id, %{"mode" => "normal"})

      assert reply["matches"] == nil

      push(socket, "unarchive-match", %{"match_id" => m1.id})

      assert {:ok, %{"matches" => matches}, _socket} =
               join(socket, "feed:" <> me.id, %{"mode" => "normal"})

      assert matches == [
               %{
                 "id" => m1.id,
                 "profile" => %{name: "mate-1", story: [], user_id: p1.id, gender: "F"},
                 "audio_only" => false,
                 "expiration_date" => expiration_date,
                 "inserted_at" => ~U[2021-09-30 12:16:05Z]
               }
             ]
    end

    test "with likes", %{socket: socket, me: me} do
      mate = onboarded_user(story: [], name: "mate", location: apple_location(), gender: "F")

      assert {:ok, %{like: %Matches.Like{}}} = Matches.like_user(mate.id, me.id)

      assert {:ok, reply, _socket} = join(socket, "feed:" <> me.id, %{"mode" => "normal"})

      assert reply == %{
               "mode" => "normal",
               "since_live_date" => Feeds.live_next_real_at(),
               "likes" => [
                 %{
                   "profile" => %{
                     name: "mate",
                     story: [],
                     user_id: mate.id,
                     gender: "F"
                   }
                 }
               ]
             }
    end

    test "with expired matches", %{socket: socket, me: me} do
      p = onboarded_user(story: [], name: "mate", location: apple_location(), gender: "F")

      m =
        insert(:expired_match,
          match_id: Ecto.Bigflake.UUID.generate(),
          user_id: me.id,
          with_user_id: p.id,
          inserted_at: ~N[2021-09-30 12:16:05]
        )

      assert {:ok, %{"expired_matches" => expired_matches}, _socket} =
               join(socket, "feed:" <> me.id, %{"mode" => "normal"})

      assert expired_matches == [
               %{
                 "id" => m.match_id,
                 "profile" => %{name: "mate", story: [], user_id: p.id, gender: "F"}
               }
             ]
    end

    test "with missed calls", %{socket: socket, me: me} do
      "user_socket:" <> token = socket.id
      mate = onboarded_user(story: [], location: apple_location(), name: "mate", gender: "F")

      # prepare pushkit devices
      :ok = Accounts.save_pushkit_device_id(me.id, token, Base.decode16!("ABABAB"), env: "prod")

      # prepare apns mock
      expect(MockAPNS, :push, 3, fn _notification -> :ok end)

      match =
        insert(:match, user_id_1: me.id, user_id_2: mate.id, inserted_at: ~N[2021-09-30 12:16:05])

      expiration_date =
        match.inserted_at
        |> DateTime.from_naive!("Etc/UTC")
        |> DateTime.add(Matches.match_ttl())

      # mate calls me
      {:ok, call_id1} = Calls.call(mate.id, me.id)

      # mate calls me
      {:ok, call_id2} = Calls.call(mate.id, me.id)

      # TODO forbid "duplicate" calls?
      {:ok, call_id3} = Calls.call(mate.id, me.id)

      assert [_, _, _] = Enum.uniq([call_id1, call_id2, call_id3])

      # me ends call, so call_id1 shouldn't be considered missed
      :ok = Calls.end_call(me.id, call_id1)

      # mate ends call, so call_id2, should be considered missed
      :ok = Calls.end_call(mate.id, call_id2)

      %Call{} = c1 = Repo.get(Call, call_id1)
      %Call{} = c2 = Repo.get(Call, call_id2)
      %Call{} = c3 = Repo.get(Call, call_id2)

      assert c1.ended_at
      assert c1.ended_by == me.id

      assert c2.ended_at
      assert c2.ended_by == mate.id

      assert {:ok, reply, _socket} = join(socket, "feed:" <> me.id, %{"mode" => "normal"})

      since_live_date = DateTime.shift_zone!(Feeds.live_next_real_at(), "Etc/UTC")

      assert reply == %{
               "mode" => "normal",
               "since_live_date" => since_live_date,
               "missed_calls" => [
                 %{
                   # TODO call without ended_at should be joined from ios?
                   "call" => %{
                     "id" => call_id2,
                     "started_at" => DateTime.from_naive!(c2.inserted_at, "Etc/UTC"),
                     "ended_at" => DateTime.from_naive!(c3.ended_at, "Etc/UTC")
                   },
                   "profile" => %{name: "mate", story: [], user_id: mate.id, gender: "F"}
                 },
                 %{
                   "call" => %{
                     "id" => call_id3,
                     "started_at" => DateTime.from_naive!(c3.inserted_at, "Etc/UTC")
                   },
                   "profile" => %{name: "mate", story: [], user_id: mate.id, gender: "F"}
                 }
               ],
               "matches" => [
                 %{
                   "id" => match.id,
                   "audio_only" => false,
                   "expiration_date" => expiration_date,
                   "inserted_at" => ~U[2021-09-30 12:16:05Z],
                   "profile" => %{gender: "F", name: "mate", story: [], user_id: mate.id}
                 }
               ]
             }

      # now with missed_calls_cursor
      assert {:ok, reply, _socket} =
               join(socket, "feed:" <> me.id, %{
                 "missed_calls_cursor" => call_id2,
                 "mode" => "normal"
               })

      assert reply == %{
               "mode" => "normal",
               "since_live_date" => since_live_date,
               "missed_calls" => [
                 %{
                   "call" => %{
                     "id" => call_id3,
                     "started_at" => DateTime.from_naive!(c3.inserted_at, "Etc/UTC")
                   },
                   "profile" => %{name: "mate", story: [], user_id: mate.id, gender: "F"}
                 }
               ],
               "matches" => [
                 %{
                   "id" => match.id,
                   "profile" => %{gender: "F", name: "mate", story: [], user_id: mate.id},
                   "audio_only" => false,
                   "expiration_date" => expiration_date,
                   "inserted_at" => ~U[2021-09-30 12:16:05Z]
                 }
               ]
             }
    end
  end

  describe "more" do
    setup :joined

    test "with no data in db", %{socket: socket} do
      ref = push(socket, "more")
      assert_reply(ref, :ok, reply)
      assert reply == %{"cursor" => nil, "feed" => []}
    end

    test "with users who haven't been online for a while", %{socket: socket} do
      long_ago = DateTime.add(DateTime.utc_now(), -62 * 24 * 60 * 60)

      for _ <- 1..3 do
        onboarded_user(
          location: apple_location(),
          accept_genders: ["F", "N", "M"],
          last_active: long_ago
        )
      end

      ref = push(socket, "more")
      assert_reply(ref, :ok, reply)
      assert reply == %{"cursor" => nil, "feed" => []}
    end

    test "with active users more than count", %{socket: socket} do
      now = DateTime.utc_now()

      [m1, m2, m3] = [
        onboarded_user(
          name: "mate-1",
          location: apple_location(),
          story: [%{"background" => %{"s3_key" => "test"}, "labels" => []}],
          gender: "F",
          accept_genders: ["M"],
          last_active: DateTime.add(now, -1)
        ),
        onboarded_user(
          name: "mate-2",
          location: apple_location(),
          story: [%{"background" => %{"s3_key" => "test"}, "labels" => []}],
          gender: "N",
          accept_genders: ["M"],
          last_active: DateTime.add(now, -2)
        ),
        onboarded_user(
          name: "mate-3",
          location: apple_location(),
          story: [%{"background" => %{"s3_key" => "test"}, "labels" => []}],
          gender: "M",
          accept_genders: ["M"],
          last_active: DateTime.add(now, -3)
        )
      ]

      set_like_ratio(m1, 1.0)
      set_like_ratio(m2, 0.5)
      set_like_ratio(m3, 0)

      ref = push(socket, "more", %{"count" => 2})
      assert_reply(ref, :ok, %{"cursor" => cursor, "feed" => feed})

      assert feed == [
               %{
                 "profile" => %{
                   user_id: m1.id,
                   name: "mate-1",
                   gender: "F",
                   story: [
                     %{
                       "background" => %{
                         "proxy" =>
                           "https://d1234.cloudfront.net/1hPLj5rf4QOwpxjzZB_S-X9SsrQMj0cayJcOCmnvXz4/fit/1000/0/sm/0/aHR0cHM6Ly9wcmV0ZW5kLXRoaXMtaXMtcmVhbC5zMy5hbWF6b25hd3MuY29tL3Rlc3Q",
                         "s3_key" => "test"
                       },
                       "labels" => []
                     }
                   ]
                 }
               },
               %{
                 "profile" => %{
                   user_id: m2.id,
                   name: "mate-2",
                   gender: "N",
                   story: [
                     %{
                       "background" => %{
                         "proxy" =>
                           "https://d1234.cloudfront.net/1hPLj5rf4QOwpxjzZB_S-X9SsrQMj0cayJcOCmnvXz4/fit/1000/0/sm/0/aHR0cHM6Ly9wcmV0ZW5kLXRoaXMtaXMtcmVhbC5zMy5hbWF6b25hd3MuY29tL3Rlc3Q",
                         "s3_key" => "test"
                       },
                       "labels" => []
                     }
                   ]
                 }
               }
             ]

      ref = push(socket, "more", %{"cursor" => cursor})

      assert_reply(ref, :ok, %{
        "cursor" => cursor,
        "feed" => feed
      })

      assert feed == [
               %{
                 "profile" => %{
                   user_id: m3.id,
                   name: "mate-3",
                   gender: "M",
                   story: [
                     %{
                       "background" => %{
                         "proxy" =>
                           "https://d1234.cloudfront.net/1hPLj5rf4QOwpxjzZB_S-X9SsrQMj0cayJcOCmnvXz4/fit/1000/0/sm/0/aHR0cHM6Ly9wcmV0ZW5kLXRoaXMtaXMtcmVhbC5zMy5hbWF6b25hd3MuY29tL3Rlc3Q",
                         "s3_key" => "test"
                       },
                       "labels" => []
                     }
                   ]
                 }
               }
             ]

      ref = push(socket, "more", %{"cursor" => cursor})
      assert_reply(ref, :ok, %{"cursor" => ^cursor, "feed" => []})
    end

    test "with age filter" do
      me =
        onboarded_user(
          location: moscow_location(),
          accept_genders: ["F"],
          min_age: 20,
          max_age: 40
        )

      socket = connected_socket(me)

      assert {:ok, _reply, socket} =
               subscribe_and_join(socket, "feed:" <> me.id, %{"mode" => "normal"})

      now = DateTime.utc_now()

      [_m1, m2, _m3] = [
        onboarded_user(
          name: "mate-1",
          location: apple_location(),
          story: [%{"background" => %{"s3_key" => "test"}, "labels" => []}],
          gender: "F",
          accept_genders: ["M"],
          birthdate: Date.add(now, -19 * 365)
        ),
        onboarded_user(
          name: "mate-2",
          location: apple_location(),
          story: [%{"background" => %{"s3_key" => "test"}, "labels" => []}],
          gender: "F",
          accept_genders: ["M"],
          birthdate: Date.add(now, -30 * 365)
        ),
        onboarded_user(
          name: "mate-3",
          location: apple_location(),
          story: [%{"background" => %{"s3_key" => "test"}, "labels" => []}],
          gender: "F",
          accept_genders: ["M"],
          birthdate: Date.add(now, -50 * 365)
        )
      ]

      ref = push(socket, "more", %{"count" => 2})
      assert_reply(ref, :ok, %{"feed" => feed})

      assert feed == [
               %{
                 "profile" => %{
                   user_id: m2.id,
                   name: "mate-2",
                   gender: "F",
                   story: [
                     %{
                       "background" => %{
                         "proxy" =>
                           "https://d1234.cloudfront.net/1hPLj5rf4QOwpxjzZB_S-X9SsrQMj0cayJcOCmnvXz4/fit/1000/0/sm/0/aHR0cHM6Ly9wcmV0ZW5kLXRoaXMtaXMtcmVhbC5zMy5hbWF6b25hd3MuY29tL3Rlc3Q",
                         "s3_key" => "test"
                       },
                       "labels" => []
                     }
                   ]
                 }
               }
             ]
    end

    test "with distance filter" do
      me =
        onboarded_user(
          location: moscow_location(),
          accept_genders: ["F"],
          distance: 10
        )

      socket = connected_socket(me)

      assert {:ok, _reply, socket} =
               subscribe_and_join(socket, "feed:" <> me.id, %{"mode" => "normal"})

      [m1, m2] = [
        onboarded_user(
          name: "mate-1",
          location: apple_location(),
          story: [%{"background" => %{"s3_key" => "test"}, "labels" => []}],
          gender: "F",
          accept_genders: ["M"]
        ),
        onboarded_user(
          name: "mate-2",
          location: moscow_location(),
          story: [%{"background" => %{"s3_key" => "test"}, "labels" => []}],
          gender: "F",
          accept_genders: ["M"]
        )
      ]

      set_like_ratio(m1, 1)
      set_like_ratio(m2, 0.5)

      ref = push(socket, "more", %{"count" => 2})
      assert_reply(ref, :ok, %{"feed" => feed})

      assert feed == [
               %{
                 "profile" => %{
                   user_id: m2.id,
                   name: "mate-2",
                   gender: "F",
                   story: [
                     %{
                       "background" => %{
                         "proxy" =>
                           "https://d1234.cloudfront.net/1hPLj5rf4QOwpxjzZB_S-X9SsrQMj0cayJcOCmnvXz4/fit/1000/0/sm/0/aHR0cHM6Ly9wcmV0ZW5kLXRoaXMtaXMtcmVhbC5zMy5hbWF6b25hd3MuY29tL3Rlc3Q",
                         "s3_key" => "test"
                       },
                       "labels" => []
                     }
                   ]
                 }
               }
             ]

      me =
        onboarded_user(
          location: moscow_location(),
          accept_genders: ["F"],
          distance: 20000
        )

      socket = connected_socket(me)

      assert {:ok, _reply, socket} =
               subscribe_and_join(socket, "feed:" <> me.id, %{"mode" => "normal"})

      ref = push(socket, "more", %{"count" => 3})
      assert_reply(ref, :ok, %{"feed" => feed})

      assert feed == [
               %{
                 "profile" => %{
                   user_id: m1.id,
                   name: "mate-1",
                   gender: "F",
                   story: [
                     %{
                       "background" => %{
                         "proxy" =>
                           "https://d1234.cloudfront.net/1hPLj5rf4QOwpxjzZB_S-X9SsrQMj0cayJcOCmnvXz4/fit/1000/0/sm/0/aHR0cHM6Ly9wcmV0ZW5kLXRoaXMtaXMtcmVhbC5zMy5hbWF6b25hd3MuY29tL3Rlc3Q",
                         "s3_key" => "test"
                       },
                       "labels" => []
                     }
                   ]
                 }
               },
               %{
                 "profile" => %{
                   user_id: m2.id,
                   name: "mate-2",
                   gender: "F",
                   story: [
                     %{
                       "background" => %{
                         "proxy" =>
                           "https://d1234.cloudfront.net/1hPLj5rf4QOwpxjzZB_S-X9SsrQMj0cayJcOCmnvXz4/fit/1000/0/sm/0/aHR0cHM6Ly9wcmV0ZW5kLXRoaXMtaXMtcmVhbC5zMy5hbWF6b25hd3MuY29tL3Rlc3Q",
                         "s3_key" => "test"
                       },
                       "labels" => []
                     }
                   ]
                 }
               }
             ]
    end

    test "previously returned profiles are not returned, feed can be reset", %{socket: socket} do
      now = DateTime.utc_now()

      for i <- 1..5 do
        onboarded_user(
          name: "mate-#{i}",
          location: apple_location(),
          story: [%{"background" => %{"s3_key" => "test"}, "labels" => []}],
          gender: "M",
          accept_genders: ["M"],
          last_active: DateTime.add(now, -i)
        )
      end

      ref = push(socket, "more", %{"count" => 3})
      assert_reply(ref, :ok, %{"cursor" => cursor, "feed" => feed0})

      initial_feed_ids =
        Enum.map(feed0, fn %{"profile" => profile} ->
          profile.user_id
        end)

      # non-nil cursor
      ref = push(socket, "more", %{"cursor" => cursor})

      assert_reply(ref, :ok, %{"cursor" => _cursor, "feed" => feed1})

      for {p, _} <- feed1 do
        assert p.user_id not in initial_feed_ids
      end

      # nil cursor
      ref = push(socket, "more", %{"cursor" => nil, "count" => 3})
      assert_reply(ref, :ok, %{"cursor" => _cursor, "feed" => feed2})

      assert feed0 == feed2
    end

    test "non-seen expired match is not returned in feed", %{socket: socket, me: me} do
      mate =
        onboarded_user(
          name: "mate",
          location: apple_location(),
          story: [%{"background" => %{"s3_key" => "test"}, "labels" => []}],
          gender: "M",
          accept_genders: ["M"]
        )

      T.Repo.insert(%T.Matches.ExpiredMatch{
        match_id: Ecto.Bigflake.UUID.generate(),
        user_id: me.id,
        with_user_id: mate.id
      })

      ref = push(socket, "more", %{"count" => 5})
      assert_reply(ref, :ok, %{"cursor" => _cursor, "feed" => []})
    end

    test "seen expired match is returned in feed", %{socket: socket, me: me} do
      mate =
        onboarded_user(
          name: "mate",
          location: apple_location(),
          story: [%{"background" => %{"s3_key" => "test"}, "labels" => []}],
          gender: "M",
          accept_genders: ["M"]
        )

      T.Repo.insert(%T.Matches.ExpiredMatch{
        match_id: Ecto.Bigflake.UUID.generate(),
        user_id: mate.id,
        with_user_id: me.id
      })

      ref = push(socket, "more", %{"count" => 5})
      assert_reply(ref, :ok, %{"cursor" => _cursor, "feed" => feed})
      assert length(feed) == 1
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

      # assert bump_likes works
      me_from_db = Repo.get!(T.Feeds.FeedProfile, me.id)
      assert me_from_db.like_ratio == 1.0

      # we got notified of like
      assert_push("invite", invite)

      assert invite == %{
               "profile" => %{
                 gender: "M",
                 name: "mate",
                 story: [],
                 user_id: mate.id
               }
             }

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # now it's our turn
      ref = push(socket, "like", %{"user_id" => mate.id})
      assert_reply(ref, :ok, %{"match_id" => match_id, "expiration_date" => ed})
      refute is_nil(ed)
      assert is_binary(match_id)

      assert_push "matched", _payload

      assert %MatchEvent{match_id: ^match_id, event: "created", timestamp: ^now} =
               Repo.get_by!(MatchEvent, match_id: match_id)
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

      assert_push "matched", %{"match" => match} = push

      now = DateTime.utc_now()
      expected_expiration_date = DateTime.add(now, Matches.match_ttl())
      assert expiration_date = match["expiration_date"]
      assert abs(DateTime.diff(expiration_date, expected_expiration_date)) <= 1

      assert %DateTime{} = inserted_at = match["inserted_at"]
      assert abs(DateTime.diff(now, inserted_at)) <= 1

      assert push == %{
               "match" => %{
                 "id" => match_id,
                 "profile" => %{name: "mate", story: [], user_id: mate.id, gender: "M"},
                 "expiration_date" => expiration_date,
                 "inserted_at" => inserted_at,
                 "audio_only" => false
               }
             }
    end
  end

  describe "failed calls to active mate" do
    setup [:joined]

    setup do
      {:ok,
       mate: onboarded_user(name: "mate", story: [], gender: "F", location: apple_location())}
    end

    setup :joined_mate

    test "missing invite", %{socket: socket, mate: mate} do
      ref = push(socket, "call", %{"user_id" => mate.id})
      assert_reply(ref, :error, reply)

      if Feeds.live_now?(mate.id) do
        assert reply == %{"reason" => "no pushkit devices available"}
      else
        assert reply == %{"reason" => "call not allowed"}
      end
    end

    test "missing pushkit devices", %{me: me, socket: socket, mate: mate} do
      insert(:match, user_id_1: me.id, user_id_2: mate.id)

      # call still fails since mate is missing pushkit devices
      ref = push(socket, "call", %{"user_id" => mate.id})
      assert_reply(ref, :error, reply)
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
          mate.id,
          mate_token,
          Base.decode16!("ABABABAB"),
          env: "prod"
        )

      :ok =
        Accounts.save_pushkit_device_id(
          mate.id,
          mate
          |> Accounts.generate_user_session_token("mobile")
          |> Accounts.UserToken.encoded_token(),
          Base.decode16!("BABABABABA"),
          env: "sandbox"
        )

      insert(:match, user_id_1: me.id, user_id_2: mate.id)

      # assert_reply(ref, :ok, _reply)

      MockAPNS
      # ABABABAB on prod -> fails!
      |> expect(:push, fn %{env: :prod} = n ->
        assert n.device_id == "ABABABAB"
        assert n.topic == "app.topic"
        assert n.push_type == "voip"
        assert n.payload["caller_id"] == me.id
        assert n.payload["caller_name"] == "that"
        assert n.payload["call_id"]
        {:error, :bad_device_token}
      end)
      # BABABABABA on sandbox -> fails!
      |> expect(:push, fn %{env: :dev} = n ->
        assert n.device_id == "BABABABABA"
        assert n.topic == "app.topic"
        assert n.push_type == "voip"
        assert n.payload["caller_id"] == me.id
        assert n.payload["caller_name"] == "that"
        assert n.payload["call_id"]
        {:error, :bad_device_token}
      end)

      # call still can fail if apns requests fail
      ref = push(socket, "call", %{"user_id" => mate.id})
      assert_reply(ref, :error, reply)
      assert reply == %{"reason" => "all pushes failed"}
    end
  end

  describe "successful calls to active mate" do
    setup [:joined]

    setup do
      {:ok, mate: onboarded_user(story: [], location: apple_location(), name: "mate")}
    end

    setup :joined_mate

    setup %{mate: mate, mate_socket: mate_socket} do
      "user_socket:" <> mate_token = mate_socket.id

      :ok =
        Accounts.save_pushkit_device_id(
          mate.id,
          mate_token,
          Base.decode16!("ABABABAB"),
          env: "prod"
        )

      :ok =
        Accounts.save_pushkit_device_id(
          mate.id,
          mate
          |> Accounts.generate_user_session_token("mobile")
          |> Accounts.UserToken.encoded_token(),
          Base.decode16!("BABABABABA"),
          env: "sandbox"
        )
    end

    test "when matched with mate", %{me: me, mate: mate, socket: socket} do
      insert(:match, user_id_1: me.id, user_id_2: mate.id)

      # these are the pushes sent to mate
      MockAPNS
      # ABABABAB on prod -> success!
      |> expect(:push, fn %{env: :prod} -> :ok end)
      # BABABABABA on sandbox -> fails!
      |> expect(:push, fn %{env: :dev} -> {:error, :bad_device_token} end)

      ref = push(socket, "call", %{"user_id" => mate.id})
      assert_reply(ref, :ok, %{"call_id" => call_id})

      assert %Call{id: ^call_id} = call = Repo.get!(Calls.Call, call_id)

      refute call.ended_at
      refute call.accepted_at
      assert call.caller_id == me.id
      assert call.called_id == mate.id
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

  describe "feed filter" do
    setup :joined

    test "is refetched when profile is updated", %{me: me, socket: socket} do
      %{feed_filter: initial_filter} = socket.assigns
      user_id = me.id
      Accounts.subscribe_for_user(user_id)
      profile = Accounts.get_profile!(user_id)
      Accounts.update_profile(profile, %{"min_age" => 31})
      new_filter = %T.Feeds.FeedFilter{initial_filter | min_age: 31}
      assert_receive {Accounts, :feed_filter_updated, ^new_filter}
    end
  end

  describe "archived-matches" do
    setup :joined

    test "works", %{me: me, socket: socket} do
      ref = push(socket, "archived-matches")
      assert_reply(ref, :ok, reply)
      assert reply == %{"archived_matches" => []}

      p1 = onboarded_user(story: [], name: "mate-1", location: apple_location(), gender: "F")

      m1 =
        insert(:match, user_id_1: me.id, user_id_2: p1.id, inserted_at: ~N[2021-09-30 12:16:05])

      ref = push(socket, "archived-matches")
      assert_reply(ref, :ok, reply)
      assert reply == %{"archived_matches" => []}

      push(socket, "archive-match", %{"match_id" => m1.id})

      ref = push(socket, "archived-matches")
      assert_reply(ref, :ok, reply)

      assert reply == %{
               "archived_matches" => [
                 %{
                   "id" => m1.id,
                   "profile" => %{name: "mate-1", story: [], user_id: p1.id, gender: "F"}
                 }
               ]
             }

      push(socket, "unarchive-match", %{"match_id" => m1.id})

      ref = push(socket, "archived-matches")
      assert_reply(ref, :ok, reply)
      assert reply == %{"archived_matches" => []}
    end
  end

  describe "open-contact, report-we-met, report-we-not-met" do
    setup :joined

    test "open-contact, report-we-not-met, report-we-met", %{me: me, socket: socket} do
      p1 = onboarded_user(story: [], name: "mate-1", location: apple_location(), gender: "F")

      m1 =
        insert(:match, user_id_1: me.id, user_id_2: p1.id, inserted_at: ~N[2021-09-30 12:16:05])

      insert(:match_contact,
        match_id: m1.id,
        contacts: %{"telegram" => "@abcde"},
        picker_id: p1.id,
        inserted_at: ~N[2021-09-30 13:16:05]
      )

      freeze_time(socket, ~U[2022-01-12 13:18:42.240988Z])
      ref = push(socket, "open-contact", %{"match_id" => m1.id, "contact_type" => "telegram"})
      assert_reply(ref, :ok, _reply)

      assert {:ok, %{"matches" => matches}, _socket} =
               join(socket, "feed:" <> me.id, %{"mode" => "normal"})

      assert matches == [
               %{
                 "id" => m1.id,
                 "profile" => %{name: "mate-1", story: [], user_id: p1.id, gender: "F"},
                 "contact" => %{
                   "contacts" => %{"telegram" => "@abcde"},
                   "picker" => p1.id,
                   "opened_contact_type" => "telegram",
                   "inserted_at" => ~U[2021-09-30 13:16:05Z],
                   "seen_at" => ~U[2022-01-12 13:18:42Z]
                 },
                 "audio_only" => false,
                 "expiration_date" => ~U[2021-10-07 12:16:05Z],
                 "inserted_at" => ~U[2021-09-30 12:16:05Z]
               }
             ]

      push(socket, "report-we-not-met", %{"match_id" => m1.id})

      assert {:ok, %{"matches" => matches}, _socket} =
               join(socket, "feed:" <> me.id, %{"mode" => "normal"})

      assert matches == [
               %{
                 "id" => m1.id,
                 "profile" => %{name: "mate-1", story: [], user_id: p1.id, gender: "F"},
                 "contact" => %{
                   "contacts" => %{"telegram" => "@abcde"},
                   "picker" => p1.id,
                   "opened_contact_type" => nil,
                   "inserted_at" => ~U[2021-09-30 13:16:05Z],
                   "seen_at" => ~U[2022-01-12 13:18:42Z]
                 },
                 "audio_only" => false,
                 "expiration_date" => ~U[2021-10-07 12:16:05Z],
                 "inserted_at" => ~U[2021-09-30 12:16:05Z]
               }
             ]

      ref = push(socket, "open-contact", %{"match_id" => m1.id, "contact_type" => "telegram"})
      assert_reply(ref, :ok, _reply)

      push(socket, "report-we-met", %{"match_id" => m1.id})

      assert {:ok, %{"matches" => matches}, _socket} =
               join(socket, "feed:" <> me.id, %{"mode" => "normal"})

      assert matches == [
               %{
                 "id" => m1.id,
                 "profile" => %{name: "mate-1", story: [], user_id: p1.id, gender: "F"},
                 "audio_only" => false,
                 "inserted_at" => ~U[2021-09-30 12:16:05Z]
               }
             ]
    end
  end

  describe "send-voicemail" do
    setup :joined

    test "failure: when match doesn't exist", %{socket: socket} do
      match_id = Ecto.UUID.generate()
      s3_key = Ecto.UUID.generate()

      ref = push(socket, "send-voicemail", %{"match_id" => match_id, "s3_key" => s3_key})
      assert_reply ref, :error, error
      assert error == %{"reason" => "voicemail not allowed"}
    end

    test "failure: when me is not part of the match", %{socket: socket} do
      u1 = onboarded_user()
      u2 = onboarded_user()
      %{id: match_id} = insert(:match, user_id_1: u1.id, user_id_2: u2.id)
      s3_key = Ecto.UUID.generate()

      ref = push(socket, "send-voicemail", %{"match_id" => match_id, "s3_key" => s3_key})
      assert_reply ref, :error, error
      assert error == %{"reason" => "voicemail not allowed"}
    end

    test "success: when users are matched, voicemail is saved and pushed to receiver", ctx do
      %{me: %{id: me_id}} = ctx
      %{id: mate_id} = mate = onboarded_user()
      %{id: match_id} = insert(:match, user_id_1: me_id, user_id_2: mate_id)

      {:ok, _reply, mate_socket} =
        mate
        |> connected_socket()
        |> join("feed:" <> mate_id, %{"mode" => "normal"})

      # mate -voice-> me

      s3_key = Ecto.UUID.generate()
      ref = push(mate_socket, "send-voicemail", %{"match_id" => match_id, "s3_key" => s3_key})

      assert_reply ref, :ok, reply
      assert Map.keys(reply) == ["id"]
      assert %{"id" => voicemail_id} = reply

      assert %Calls.Voicemail{
               id: ^voicemail_id,
               caller_id: ^mate_id,
               match_id: ^match_id,
               s3_key: ^s3_key,
               inserted_at: inserted_at
             } = Repo.get(Calls.Voicemail, voicemail_id)

      assert_push "voicemail_received", %{"url" => url} = push

      assert push == %{
               "id" => voicemail_id,
               "inserted_at" => DateTime.from_naive!(inserted_at, "Etc/UTC"),
               "match_id" => match_id,
               "s3_key" => s3_key,
               "url" => url
             }

      assert String.starts_with?(
               push["url"],
               "https://s3.eu-north-1.amazonaws.com/pretend-this-is-real/" <> s3_key
             )
    end
  end

  describe "listen-voicemail" do
    setup :joined

    test "success: sets voicemail's listened_at date", ctx do
      %{me: %{id: me_id}, socket: socket} = ctx
      %{id: mate_id} = mate = onboarded_user()
      %{id: match_id} = insert(:match, user_id_1: me_id, user_id_2: mate_id)

      # me -voice-> mate

      ref =
        push(socket, "send-voicemail", %{
          "match_id" => match_id,
          "s3_key" => Ecto.UUID.generate()
        })

      assert_reply ref, :ok, %{"id" => voicemail_id}
      assert %Calls.Voicemail{listened_at: nil} = Repo.get(Calls.Voicemail, voicemail_id)

      # mate -listen-> voice

      {:ok, _reply, mate_socket} =
        mate
        |> connected_socket()
        |> subscribe_and_join("feed:" <> mate_id, %{"mode" => "normal"})

      now = DateTime.utc_now()
      freeze_time(mate_socket, now)

      ref = push(mate_socket, "listen-voicemail", %{"id" => voicemail_id})
      assert_reply ref, :ok

      assert %Calls.Voicemail{listened_at: listened_at} = Repo.get(Calls.Voicemail, voicemail_id)
      assert listened_at == DateTime.truncate(now, :second)
    end
  end

  describe "list-interactions" do
    setup :joined

    test "success: lists all interactions for a match", %{me: me, socket: socket} do
      mate = onboarded_user()
      match = insert(:match, user_id_1: me.id, user_id_2: mate.id)

      # no interactions in the beginning
      ref = push(socket, "list-interactions", %{"match_id" => match.id})
      assert_reply ref, :ok, reply
      assert reply == %{"interactions" => []}

      # add some interactions (just enough to test all MatchView clauses)

      # - offer and cancel contacts
      Matches.save_contacts_offer_for_match(me.id, match.id, %{"telegram" => "@asdfasdfasf"})
      assert_push "interaction", %{"interaction" => %{"type" => "contact_offer"}}

      Matches.cancel_contacts_for_match(me.id, match.id)
      assert_push "interaction", %{"interaction" => %{"type" => "contact_cancel"}}

      slots = [
        "2021-03-23 13:15:00Z",
        "2021-03-23 13:30:00Z",
        "2021-03-23 14:00:00Z",
        "2021-03-23 14:15:00Z",
        "2021-03-23 14:30:00Z"
      ]

      now = ~U[2021-03-23 14:12:00Z]

      # - offer and cancel timelots
      Matches.save_slots_offer_for_match(me.id, match.id, slots, now)
      assert_push "interaction", %{"interaction" => %{"type" => "slots_offer"}}

      Matches.cancel_slot_for_match(me.id, match.id)
      assert_push "interaction", %{"interaction" => %{"type" => "slot_cancel"}}

      # - offer and accept timelots
      Matches.save_slots_offer_for_match(me.id, match.id, slots, now)
      assert_push "interaction", %{"interaction" => %{"type" => "slots_offer"}}

      Matches.accept_slot_for_match(mate.id, match.id, _slot = "2021-03-23 14:00:00Z", now)
      assert_push "interaction", %{"interaction" => %{"type" => "slot_accept"}}

      # - send voicemail
      {:ok, %Calls.Voicemail{} = voice} =
        Calls.voicemail_save_message(me.id, match.id, Ecto.UUID.generate())

      assert_push "interaction", %{"interaction" => %{"type" => "voicemail"}}

      # - attempt, accept, and end call
      insert(:push_kit_device,
        device_id: "ABAB",
        user: mate,
        token: build(:user_token, user: mate)
      )

      expect(MockAPNS, :push, fn _notification -> :ok end)

      {:ok, call_id} = Calls.call(me.id, mate.id)

      assert_push "interaction", %{
        "interaction" => %{"type" => "call"}
      }

      :ok = Calls.accept_call(call_id, _now = ~U[2021-03-23 14:01:02Z])

      assert_push "interaction", %{
        "interaction" => %{"type" => "call", "accepted_at" => _}
      }

      :ok = Calls.end_call(mate.id, call_id, _now = ~U[2021-03-23 14:05:13Z])

      assert_push "interaction", %{
        "interaction" => %{"type" => "call", "accepted_at" => _, "ended_at" => _}
      }

      # now we have all possible interactions
      ref = push(socket, "list-interactions", %{"match_id" => match.id})
      assert_reply ref, :ok, %{"interactions" => interactions}

      mate_id = mate.id
      me_id = me.id
      voicemail_id = voice.id
      voicemail_s3_key = voice.s3_key

      assert [
               # - offer and cancel contacts
               %{
                 "contacts" => %{"telegram" => "@asdfasdfasf"},
                 "id" => _,
                 "inserted_at" => %DateTime{},
                 "picker" => ^mate_id,
                 "type" => "contact_offer"
               },
               %{
                 "at" => %DateTime{},
                 "by" => ^me_id,
                 "id" => _,
                 "type" => "contact_cancel"
               },
               # - offer and cancel timelots
               %{
                 "id" => _,
                 "inserted_at" => %DateTime{},
                 "picker" => ^mate_id,
                 "slots" => [
                   "2021-03-23T14:00:00Z",
                   "2021-03-23T14:15:00Z",
                   "2021-03-23T14:30:00Z"
                 ],
                 "type" => "slots_offer"
               },
               %{
                 "by_user_id" => ^me_id,
                 "cancelled_at" => %DateTime{},
                 "id" => _,
                 "type" => "slot_cancel"
               },
               # - offer and accept timelots
               %{
                 "id" => _,
                 "inserted_at" => %DateTime{},
                 "picker" => ^mate_id,
                 "slots" => [
                   "2021-03-23T14:00:00Z",
                   "2021-03-23T14:15:00Z",
                   "2021-03-23T14:30:00Z"
                 ],
                 "type" => "slots_offer"
               },
               %{
                 "accepted_at" => %DateTime{},
                 "id" => _,
                 "selected_slot" => "2021-03-23T14:00:00Z",
                 "type" => "slot_accept"
               },
               # - send voicemail
               %{
                 "caller" => ^me_id,
                 "id" => ^voicemail_id,
                 "inserted_at" => %DateTime{},
                 "s3_key" => ^voicemail_s3_key,
                 "type" => "voicemail",
                 "url" => _
               },
               # - complete call
               %{
                 "attempted_at" => %DateTime{},
                 "accepted_at" => "2021-03-23T14:01:02Z",
                 "ended_at" => "2021-03-23T14:05:13Z",
                 "call_id" => ^call_id,
                 "id" => ^call_id,
                 "type" => "call"
               }
             ] = interactions
    end
  end

  defp joined(%{socket: socket, me: me}) do
    assert {:ok, _reply, socket} =
             subscribe_and_join(socket, "feed:" <> me.id, %{"mode" => "normal"})

    {:ok, socket: socket}
  end

  defp joined_mate(%{mate: mate}) do
    socket = connected_socket(mate)
    {:ok, _reply, socket} = join(socket, "feed:" <> mate.id, %{"mode" => "normal"})
    {:ok, mate_socket: socket}
  end
end
