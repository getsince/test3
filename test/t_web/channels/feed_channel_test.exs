defmodule TWeb.FeedChannelTest do
  use TWeb.ChannelCase, async: true

  alias T.{Accounts, Matches, News}
  alias Matches.Match

  setup do
    me = onboarded_user(location: moscow_location(), accept_genders: ["F", "N", "M"])
    {:ok, me: me, socket: connected_socket(me)}
  end

  describe "join" do
    test "with invalid topic", %{socket: socket} do
      assert {:error, %{"error" => "forbidden"}} = join(socket, "feed:" <> Ecto.UUID.generate())
    end

    test "shows private pages of matches", %{socket: socket, me: me} do
      stacy =
        onboarded_user(
          name: "Private Stacy",
          location: apple_location(),
          story: [
            %{"background" => %{"s3_key" => "public1"}, "labels" => [], "size" => [400, 100]},
            %{
              "background" => %{"s3_key" => "private"},
              "blurred" => %{"s3_key" => "blurred"},
              "labels" => [
                %{
                  "value" => "some private info",
                  "position" => [100, 100]
                }
              ],
              "size" => [100, 400]
            }
          ],
          gender: "F",
          accept_genders: ["M"]
        )

      insert(:match, user_id_1: me.id, user_id_2: stacy.id)

      assert {:ok, %{"matches" => [%{"profile" => %{story: [public, private]}}]}, _socket} =
               join(socket, "feed:" <> me.id)

      assert Map.keys(public) == ["background", "labels", "size"]
      assert Map.keys(private) == ["background", "labels", "private", "size"]
      assert %{"private" => true} = private
    end

    test "with matches", %{socket: socket, me: me} do
      [p1, p2, p3] = [
        onboarded_user(story: [], name: "mate-1", location: apple_location(), gender: "F"),
        onboarded_user(story: [], name: "mate-2", location: apple_location(), gender: "N"),
        onboarded_user(story: [], name: "mate-3", location: apple_location(), gender: "M")
      ]

      [m1, m2, m3] = [
        insert(:match, user_id_1: me.id, user_id_2: p1.id, inserted_at: ~N[2021-09-30 12:16:05]),
        insert(:match, user_id_1: me.id, user_id_2: p2.id, inserted_at: ~N[2021-09-30 12:16:06]),
        insert(:match, user_id_1: me.id, user_id_2: p3.id, inserted_at: ~N[2021-09-30 12:16:07])
      ]

      # first and second matches are seen
      :ok = Matches.mark_match_seen(me.id, m1.id)
      :ok = Matches.mark_match_seen(me.id, m2.id)
      Matches.save_contact_click(m1.id)

      assert {:ok, %{"matches" => matches}, _socket} = join(socket, "feed:" <> me.id)

      assert matches == [
               %{
                 "id" => m3.id,
                 "profile" => %{name: "mate-3", story: [], user_id: p3.id, gender: "M"},
                 "inserted_at" => ~U[2021-09-30 12:16:07Z],
                 "expiration_date" => ~U[2021-10-01 12:16:07Z]
               },
               %{
                 "id" => m2.id,
                 "profile" => %{name: "mate-2", story: [], user_id: p2.id, gender: "N"},
                 "inserted_at" => ~U[2021-09-30 12:16:06Z],
                 "expiration_date" => ~U[2021-10-01 12:16:06Z],
                 "seen" => true
               },
               %{
                 "id" => m1.id,
                 "profile" => %{name: "mate-1", story: [], user_id: p1.id, gender: "F"},
                 "inserted_at" => ~U[2021-09-30 12:16:05Z],
                 "seen" => true
               }
             ]
    end

    test "with likes", %{socket: socket, me: me} do
      mate1 = onboarded_user(story: [], name: "mate-1", location: apple_location(), gender: "F")
      mate2 = onboarded_user(story: [], name: "mate-2", location: apple_location(), gender: "F")

      assert {:ok, %{like: %Matches.Like{}}} = Matches.like_user(mate1.id, me.id)
      assert {:ok, %{like: %Matches.Like{}}} = Matches.like_user(mate2.id, me.id)
      assert :ok = Matches.mark_like_seen(me.id, mate2.id)

      assert {:ok, reply, _socket} = join(socket, "feed:" <> me.id, %{"mode" => "normal"})

      assert reply == %{
               "likes" => [
                 %{
                   "profile" => %{
                     name: "mate-1",
                     story: [],
                     user_id: mate1.id,
                     gender: "F",
                     distance: nil
                   }
                 },
                 %{
                   "profile" => %{
                     name: "mate-2",
                     story: [],
                     user_id: mate2.id,
                     gender: "F",
                     distance: nil
                   },
                   "seen" => true
                 }
               ]
             }
    end

    test "with news", %{socket: socket, me: me} do
      import Ecto.Query

      {1, _} =
        News.SeenNews
        |> where(user_id: ^me.id)
        |> Repo.delete_all()

      assert {:ok, %{"news" => news}, socket} = join(socket, "feed:" <> me.id)

      assert [
               _first_news_item = %{id: 1, story: story1},
               _second_news_item = %{id: 2, story: story2}
             ] = news

      assert [p1, p2, p3, p4, p5] = story1
      assert [p6] = story2

      for page <- [p1, p2, p3, p5, p6] do
        assert %{"background" => %{"color" => _}, "labels" => _, "size" => _} = page
      end

      assert %{
               "blurred" => %{
                 "s3_key" => "5cfbe96c-e456-43bb-8d3a-98e849c00d5d",
                 "proxy" => "https://d1234.cloudfront.net/" <> _
               },
               "private" => true
             } = p4

      tg_contact = Enum.find(p2["labels"], fn label -> label["question"] == "telegram" end)
      ig_contact = Enum.find(p2["labels"], fn label -> label["question"] == "instagram" end)

      assert Map.take(tg_contact, ["answer", "url"]) == %{
               "answer" => "getsince",
               "url" => "https://t.me/getsince"
             }

      assert Map.take(ig_contact, ["answer", "url"]) == %{
               "answer" => "getsince.app",
               "url" => "https://instagram.com/getsince.app"
             }

      ref = push(socket, "seen", %{"news_story_id" => 1})
      assert_reply ref, :ok, _

      assert {:ok, %{"news" => news}, socket} = join(socket, "feed:" <> me.id)
      assert length(news) == 1

      ref = push(socket, "seen", %{"news_story_id" => 2})
      assert_reply ref, :ok, _

      assert {:ok, reply, _socket} = join(socket, "feed:" <> me.id)
      refute reply["news"]

      assert 2 == Repo.get!(News.SeenNews, me.id).last_id
    end

    test "without todos", %{socket: socket, me: me} do
      assert {:ok, reply, _socket} = join(socket, "feed:" <> me.id)
      refute reply["todos"]
    end

    test "with todos", %{socket: socket, me: me} do
      {:ok, _profile} =
        Accounts.update_profile(me.id, %{
          "story" => [
            %{
              "background" => %{"s3_key" => "photo.jpg"},
              "labels" => []
            }
          ]
        })

      assert {:ok, %{"todos" => todos}, _socket} = join(socket, "feed:" <> me.id)

      assert [_first_todos_item = %{story: story}] = todos
      assert [p1] = story

      assert %{"background" => %{"color" => _}, "labels" => _, "size" => _} = p1
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
                   ],
                   distance: 9510
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
                   ],
                   distance: 9510
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
                   ],
                   distance: 9510
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
                   ],
                   distance: 9510
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
                   ],
                   distance: 0
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
                   ],
                   distance: 9510
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
                   ],
                   distance: 0
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
  end

  describe "like" do
    setup :joined

    setup do
      stacy =
        onboarded_user(
          name: "Private Stacy",
          location: apple_location(),
          story: [
            %{"background" => %{"s3_key" => "public1"}, "labels" => [], "size" => [400, 100]},
            %{
              "background" => %{"s3_key" => "private"},
              "blurred" => %{"s3_key" => "blurred"},
              "labels" => [
                %{
                  "value" => "some private info",
                  "position" => [100, 100]
                }
              ],
              "size" => [100, 400]
            }
          ],
          gender: "F",
          accept_genders: ["M"]
        )

      {:ok, mate: stacy}
    end

    setup :joined_mate

    test "when already liked by mate", ctx do
      %{
        me: me,
        socket: socket,
        mate: mate,
        mate_socket: mate_socket
      } = ctx

      # mate likes us
      ref = push(mate_socket, "like", %{"user_id" => me.id})
      assert_reply(ref, :ok, reply)
      assert reply == %{}

      # assert bump_likes works
      me_from_db = Repo.get!(T.Feeds.FeedProfile, me.id)
      assert me_from_db.like_ratio == 1.0

      # we got notified of like
      assert_push("invite", %{"profile" => %{story: [public, private] = story}} = invite)

      assert invite == %{
               "profile" => %{
                 gender: "F",
                 name: "Private Stacy",
                 story: story,
                 user_id: mate.id,
                 distance: nil
               }
             }

      # when we get notified of like, we are not showing private pages of the liker
      assert Map.keys(public) == ["background", "labels", "size"]
      assert Map.keys(private) == ["blurred", "private"]

      assert %{
               "blurred" => %{"s3_key" => "blurred", "proxy" => "https://" <> _},
               "private" => true
             } = private

      # now it's our turn
      ref = push(socket, "like", %{"user_id" => mate.id})

      assert_reply(ref, :ok, %{
        "match_id" => match_id,
        "expiration_date" => expiration_date,
        "profile" => %{story: [public, private]}
      })

      assert expiration_date
      assert is_binary(match_id)

      assert_push "matched", _payload

      # when we are matched, we can see private pages of the liker (now mate)
      assert Map.keys(public) == ["background", "labels", "size"]
      assert Map.keys(private) == ["background", "labels", "private", "size"]
      assert %{"private" => true} = private
    end

    test "when not yet liked by mate", ctx do
      %{
        me: me,
        socket: socket,
        mate: mate,
        mate_socket: mate_socket
      } = ctx

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

      assert %{"match" => %{"profile" => %{story: [public, private] = story}}} = push

      assert push == %{
               "match" => %{
                 "id" => match_id,
                 "profile" => %{
                   name: "Private Stacy",
                   story: story,
                   user_id: mate.id,
                   gender: "F"
                 },
                 "expiration_date" => expiration_date,
                 "inserted_at" => inserted_at
               }
             }

      # when we are matched, we can see private pages
      assert Map.keys(public) == ["background", "labels", "size"]
      assert Map.keys(private) == ["background", "labels", "private", "size"]
      assert %{"private" => true} = private
    end

    test "seen-like", ctx do
      import Ecto.Query

      %{me: me, socket: socket, mate: mate} = ctx

      # mate likes us
      {:ok, _} = Matches.like_user(mate.id, me.id)

      # we see mate's like
      ref = push(socket, "seen-like", %{"user_id" => mate.id})
      assert_reply ref, :ok, _reply

      assert %Matches.Like{seen: true} =
               Matches.Like
               |> where(by_user_id: ^mate.id)
               |> where(user_id: ^me.id)
               |> Repo.one!()
    end
  end

  describe "seen-match" do
    setup :joined

    test "marks match as seen", %{me: me, socket: socket} do
      mate = onboarded_user()
      match = insert(:match, user_id_1: me.id, user_id_2: mate.id)

      ref = push(socket, "seen-match", %{"match_id" => match.id})
      assert_reply ref, :ok, _reply

      assert [%Match{seen: true}] = Matches.list_matches(me.id)
    end
  end

  describe "calls" do
    setup [:joined]

    test "result in deprecation warning", %{socket: socket} do
      ref = push(socket, "call", _params = %{})
      assert_reply ref, :error, reply

      assert reply == %{
               alert: %{
                 title: "Deprecation warning",
                 body: "Calls are no longer supported, please upgrade."
               }
             }
    end
  end

  describe "offer-slots" do
    setup :joined

    test "results in deprecation warning", %{socket: socket} do
      ref = push(socket, "offer-slots", _params = %{})
      assert_reply ref, :error, reply

      assert reply == %{
               alert: %{
                 title: "Deprecation warning",
                 body: "Calls are no longer supported, please upgrade."
               }
             }
    end
  end

  describe "pick-slot" do
    setup :joined

    test "results in deprecation warning", %{socket: socket} do
      ref = push(socket, "pick-slot", _params = %{})
      assert_reply ref, :error, reply

      assert reply == %{
               alert: %{
                 title: "Deprecation warning",
                 body: "Calls are no longer supported, please upgrade."
               }
             }
    end
  end

  describe "cancel-slot" do
    setup :joined

    test "results in deprecation warning", %{socket: socket} do
      ref = push(socket, "cancel-slot", _params = %{})
      assert_reply ref, :error, reply

      assert reply == %{
               alert: %{
                 title: "Deprecation warning",
                 body: "Calls are no longer supported, please upgrade."
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
      Accounts.update_profile(me.id, %{"min_age" => 31})

      new_filter = %T.Feeds.FeedFilter{initial_filter | min_age: 31}
      assert_receive {Accounts, :feed_filter_updated, ^new_filter}
    end
  end

  describe "send-voicemail" do
    setup :joined

    test "results in deprecation warning", %{socket: socket} do
      ref = push(socket, "send-voicemail", _params = %{})
      assert_reply ref, :error, reply

      assert reply == %{
               alert: %{
                 title: "Deprecation warning",
                 body: "Voicemail is no longer supported, please upgrade."
               }
             }
    end
  end

  describe "listen-voicemail" do
    setup :joined

    test "results in deprecation warning", %{socket: socket} do
      ref = push(socket, "listen-voicemail", _params = %{})
      assert_reply ref, :error, reply

      assert reply == %{
               alert: %{
                 title: "Deprecation warning",
                 body: "Voicemail is no longer supported, please upgrade."
               }
             }
    end
  end

  describe "private stories" do
    setup :joined

    setup do
      now = DateTime.utc_now()

      stacy =
        onboarded_user(
          name: "Private Stacy",
          location: apple_location(),
          story: [
            %{"background" => %{"s3_key" => "public1"}, "labels" => [], "size" => [400, 100]},
            %{
              "background" => %{"s3_key" => "private"},
              "blurred" => %{"s3_key" => "blurred"},
              "labels" => [
                %{
                  "value" => "some private info",
                  "position" => [100, 100]
                }
              ],
              "size" => [100, 400]
            }
          ],
          gender: "F",
          accept_genders: ["M"],
          last_active: DateTime.add(now, -1)
        )

      {:ok, stacy: stacy}
    end

    test "more: private stories are blurred", %{socket: socket} do
      ref = push(socket, "more")
      assert_reply(ref, :ok, %{"feed" => feed})

      assert [%{"profile" => %{story: [public, private]}}] = feed

      assert Map.keys(public) == ["background", "labels", "size"]
      assert Map.keys(private) == ["blurred", "private"]

      assert %{
               "blurred" => %{
                 "s3_key" => "blurred",
                 "proxy" => "https://d1234.cloudfront.net/" <> _
               },
               "private" => true
             } = private
    end

    test "matched: private story becomes visible", %{me: me, stacy: stacy} do
      Matches.like_user(me.id, stacy.id)
      Matches.like_user(stacy.id, me.id)

      assert_push "matched", %{"match" => %{"profile" => %{story: [public, private]}}}
      assert Map.keys(public) == ["background", "labels", "size"]
      assert Map.keys(private) == ["background", "labels", "private", "size"]
      assert %{"private" => true} = private
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
