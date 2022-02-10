defmodule TWeb.FeedChannelTest do
  use TWeb.ChannelCase, async: true

  alias T.{Accounts, Matches}
  alias Matches.Match

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

      assert {:ok, %{"matches" => matches}, _socket} =
               join(socket, "feed:" <> me.id, %{"mode" => "normal"})

      assert matches == [
               %{
                 "id" => m6.id,
                 "profile" => %{name: "mate-6", story: [], user_id: p6.id, gender: "F"},
                 "inserted_at" => ~U[2021-09-30 12:16:10Z],
                 "expiration_date" => ~U[2021-10-07 12:16:10Z]
               },
               %{
                 "id" => m5.id,
                 "profile" => %{name: "mate-5", story: [], user_id: p5.id, gender: "F"},
                 "inserted_at" => ~U[2021-09-30 12:16:09Z],
                 "expiration_date" => ~U[2021-10-07 12:16:09Z]
               },
               %{
                 "id" => m4.id,
                 "profile" => %{name: "mate-4", story: [], user_id: p4.id, gender: "F"},
                 "inserted_at" => ~U[2021-09-30 12:16:08Z],
                 "expiration_date" => ~U[2021-10-07 12:16:08Z]
               },
               %{
                 "id" => m3.id,
                 "profile" => %{name: "mate-3", story: [], user_id: p3.id, gender: "M"},
                 "inserted_at" => ~U[2021-09-30 12:16:07Z],
                 "expiration_date" => ~U[2021-10-07 12:16:07Z]
               },
               %{
                 "id" => m2.id,
                 "profile" => %{name: "mate-2", story: [], user_id: p2.id, gender: "N"},
                 "inserted_at" => ~U[2021-09-30 12:16:06Z],
                 "expiration_date" => ~U[2021-10-07 12:16:06Z]
               },
               %{
                 "id" => m1.id,
                 "profile" => %{name: "mate-1", story: [], user_id: p1.id, gender: "F"},
                 "inserted_at" => ~U[2021-09-30 12:16:05Z],
                 "expiration_date" => ~U[2021-10-07 12:16:05Z]
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

      # now it's our turn
      ref = push(socket, "like", %{"user_id" => mate.id})
      assert_reply(ref, :ok, %{"match_id" => match_id, "expiration_date" => ed})
      refute is_nil(ed)
      assert is_binary(match_id)

      assert_push "matched", _payload
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
                 "inserted_at" => inserted_at
               }
             }
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
