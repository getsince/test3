defmodule TWeb.FeedChannelTest do
  use TWeb.ChannelCase, async: true

  alias T.{Accounts, Matches, News}
  alias Matches.{Match, MatchEvent}

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
      [p1, p2, p3, p4] = [
        onboarded_user(story: [], name: "mate-1", location: apple_location(), gender: "F"),
        onboarded_user(story: [], name: "mate-2", location: apple_location(), gender: "N"),
        onboarded_user(story: [], name: "mate-3", location: apple_location(), gender: "M"),
        onboarded_user(story: [], name: "mate-4", location: apple_location(), gender: "F")
      ]

      [m1, m2, m3, m4] = [
        insert(:match, user_id_1: me.id, user_id_2: p1.id, inserted_at: ~N[2021-09-30 12:16:05]),
        insert(:match, user_id_1: me.id, user_id_2: p2.id, inserted_at: ~N[2021-09-30 12:16:06]),
        insert(:match, user_id_1: me.id, user_id_2: p3.id, inserted_at: ~N[2021-09-30 12:16:07]),
        insert(:match, user_id_1: me.id, user_id_2: p4.id, inserted_at: ~N[2021-09-30 12:16:08])
      ]

      now = ~U[2021-09-30 14:47:00.123456Z]

      # first match is in contacts exchange interaction mode
      Matches.save_contacts_offer_for_match(
        me.id,
        m1.id,
        _contacts = %{"telegram" => "@abcde"},
        now
      )

      # first match is also seen
      :ok = Matches.mark_match_seen(me.id, m1.id)

      # and then sends contacts as well
      Matches.save_contacts_offer_for_match(
        me.id,
        m2.id,
        _contacts = %{"whatsapp" => "+79666666666"},
        now
      )

      # and second match is also seen
      :ok = Matches.mark_match_seen(me.id, m2.id)

      # fourth match doesn't have any interaction
      # ¯\_ (ツ)_/¯

      assert {:ok, %{"matches" => matches}, _socket} =
               join(socket, "feed:" <> me.id, %{"mode" => "normal"})

      last_interaction_id = fn position ->
        match = Enum.at(matches, position)
        match["last_interaction_id"]
      end

      assert matches == [
               %{
                 "id" => m4.id,
                 "profile" => %{name: "mate-4", story: [], user_id: p4.id, gender: "F"},
                 "audio_only" => false,
                 "expiration_date" => ~U[2021-10-01 12:16:08Z],
                 "inserted_at" => ~U[2021-09-30 12:16:08Z]
               },
               %{
                 "id" => m3.id,
                 "profile" => %{name: "mate-3", story: [], user_id: p3.id, gender: "M"},
                 "audio_only" => false,
                 "expiration_date" => ~U[2021-10-01 12:16:07Z],
                 "inserted_at" => ~U[2021-09-30 12:16:07Z]
               },
               %{
                 "id" => m2.id,
                 "profile" => %{name: "mate-2", story: [], user_id: p2.id, gender: "N"},
                 "contact" => %{
                   "contacts" => %{"whatsapp" => "+79666666666"},
                   "inserted_at" => ~U[2021-09-30 14:47:00Z],
                   "opened_contact_type" => nil,
                   "picker" => p2.id
                 },
                 "audio_only" => false,
                 "inserted_at" => ~U[2021-09-30 12:16:06Z],
                 "last_interaction_id" => last_interaction_id.(2),
                 "seen" => true
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
                 "inserted_at" => ~U[2021-09-30 12:16:05Z],
                 "last_interaction_id" => last_interaction_id.(3),
                 "seen" => true
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
                     gender: "F"
                   }
                 },
                 %{
                   "profile" => %{name: "mate-2", story: [], user_id: mate2.id, gender: "F"},
                   "seen" => true
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

    test "with news", %{socket: socket, me: me} do
      import Ecto.Query

      {1, _} =
        News.SeenNews
        |> where(user_id: ^me.id)
        |> Repo.delete_all()

      assert {:ok, %{"news" => news}, socket} = join(socket, "feed:" <> me.id)

      assert [_first_news_item = %{id: 1, story: story}] = news
      assert [p1, p2, p3, p4, p5] = story

      for page <- [p1, p2, p3, p5] do
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

      # should be no-op since the user has already seen story with id=1
      ref = push(socket, "seen", %{"news_story_id" => 0})
      assert_reply ref, :ok, _

      assert {:ok, reply, _socket} = join(socket, "feed:" <> me.id)
      refute reply["news"]

      assert 1 == Repo.get!(News.SeenNews, me.id).last_id
    end

    test "without todos", %{socket: socket, me: me} do
      assert {:ok, reply, _socket} = join(socket, "feed:" <> me.id)
      refute reply["todos"]
    end

    test "with todos", %{socket: socket, me: me} do
      {:ok, _profile} =
        Accounts.update_profile(me.profile, %{
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
                 user_id: mate.id
               }
             }

      # when we get notified of like, we are not showing private pages of the liker
      assert Map.keys(public) == ["background", "labels", "size"]
      assert Map.keys(private) == ["blurred", "private"]

      assert %{
               "blurred" => %{"s3_key" => "blurred", "proxy" => "https://" <> _},
               "private" => true
             } = private

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # now it's our turn
      ref = push(socket, "like", %{"user_id" => mate.id})

      assert_reply(ref, :ok, %{
        "match_id" => match_id,
        "expiration_date" => ed,
        "profile" => %{story: [public, private]}
      })

      refute is_nil(ed)
      assert is_binary(match_id)

      assert_push "matched", _payload

      assert %MatchEvent{match_id: ^match_id, event: "created", timestamp: ^now} =
               Repo.get_by!(MatchEvent, match_id: match_id)

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
                 "inserted_at" => inserted_at,
                 "audio_only" => false
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

  # test doesn't make sense since "report-we-met" doesn't affect match expiration now, should be removed
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
                 "expiration_date" => ~U[2021-10-01 12:16:05Z],
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
                 "expiration_date" => ~U[2021-10-01 12:16:05Z],
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
                 "expiration_date" => ~U[2021-10-01 12:16:05Z],
                 "inserted_at" => ~U[2021-09-30 12:16:05Z]
               }
             ]
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

      # - offer contacts
      Matches.save_contacts_offer_for_match(me.id, match.id, %{"telegram" => "@asdfasdfasf"})
      assert_push "interaction", %{"interaction" => %{"type" => "contact_offer"}}

      # now we have all possible interactions
      ref = push(socket, "list-interactions", %{"match_id" => match.id})
      assert_reply ref, :ok, %{"interactions" => interactions}

      me_id = me.id

      assert [
               # - offer contacts
               %{
                 "id" => _,
                 "type" => "contact_offer",
                 "contacts" => %{"telegram" => "@asdfasdfasf"},
                 "by_user_id" => ^me_id,
                 "inserted_at" => %DateTime{}
               }
             ] = interactions
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
