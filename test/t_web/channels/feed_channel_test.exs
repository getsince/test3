defmodule TWeb.FeedChannelTest do
  use TWeb.ChannelCase, async: true

  alias T.{Accounts, Chats, Feeds}
  alias Chats.Message

  setup do
    me = onboarded_user(location: moscow_location(), accept_genders: ["F", "N", "M"])

    {:ok,
     me: me, socket: connected_socket(me), socket_with_old_version: connected_socket(me, "6.9.0")}
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

    test "shows private pages of matched chats", %{socket: socket, me: me} do
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

      insert(:chat, user_id_1: me.id, user_id_2: stacy.id, matched: true)

      assert {:ok, %{"chats" => [%{"profile" => %{story: [public, private]}}]}, _socket} =
               join(socket, "feed:" <> me.id)

      assert Map.keys(public) == ["background", "labels", "size"]
      assert Map.keys(private) == ["background", "labels", "private", "size"]
      assert %{"private" => true} = private
    end

    test "with feed if asked", %{socket: socket, me: me} do
      assert {:ok, %{}, _socket} = join(socket, "feed:" <> me.id)

      assert {:ok, %{"feed" => feed}, _socket} =
               join(socket, "feed:" <> me.id, %{"need_feed" => true})

      assert feed == []

      p = onboarded_user(story: [], name: "mate", location: apple_location(), gender: "F")

      # so that our onboarded_user is not treated as the first-time user when being served feed
      not_me = insert(:user)
      insert(:seen_profile, by_user: me, user: not_me, inserted_at: DateTime.utc_now())

      assert {:ok, %{}, _socket} = join(socket, "feed:" <> me.id)

      assert {:ok, %{"feed" => feed}, _socket} =
               join(socket, "feed:" <> me.id, %{"need_feed" => true})

      assert feed == [
               %{
                 "profile" => %{
                   address: %{
                     "en_US" => %{
                       "city" => "Buenos Aires",
                       "country" => "Argentina",
                       "iso_country_code" => "AR",
                       "state" => "Autonomous City of Buenos Aires"
                     }
                   },
                   distance: 9510,
                   gender: "F",
                   name: "mate",
                   story: [],
                   user_id: p.id
                 }
               }
             ]
    end

    test "with chats", %{socket: socket, me: me} do
      [p1, p2, p3] = [
        onboarded_user(story: [], name: "mate-1", location: apple_location(), gender: "F"),
        onboarded_user(story: [], name: "mate-2", location: apple_location(), gender: "N"),
        onboarded_user(story: [], name: "mate-3", location: apple_location(), gender: "M")
      ]

      [c1, c2, c3] = [
        insert(:chat, user_id_1: me.id, user_id_2: p1.id, inserted_at: ~N[2021-09-30 12:16:05]),
        insert(:chat, user_id_1: me.id, user_id_2: p2.id, inserted_at: ~N[2021-09-30 12:16:06]),
        insert(:chat, user_id_1: me.id, user_id_2: p3.id, inserted_at: ~N[2021-09-30 12:16:07])
      ]

      # second chat has one message
      {:ok, %Message{id: message_id_1}} =
        Chats.save_message(
          p2.id,
          me.id,
          %{"question" => "text", "value" => "hey mama"}
        )

      # third chat had two messages
      {:ok, %Message{id: message_id_2}} =
        Chats.save_message(
          p3.id,
          me.id,
          %{"question" => "telegram", "answer" => "durov"}
        )

      {:ok, %Message{id: message_id_3}} =
        Chats.save_message(
          me.id,
          p3.id,
          %{"question" => "audio", "s3_key" => "abcd"}
        )

      assert {:ok, %{"chats" => chats}, _socket} = join(socket, "feed:" <> me.id)

      assert chats == [
               %{
                 "id" => c3.id,
                 "profile" => %{
                   name: "mate-3",
                   story: [],
                   user_id: p3.id,
                   gender: "M",
                   distance: 9510,
                   address: %{
                     "en_US" => %{
                       "city" => "Buenos Aires",
                       "state" => "Autonomous City of Buenos Aires",
                       "country" => "Argentina",
                       "iso_country_code" => "AR"
                     }
                   }
                 },
                 "inserted_at" => ~U[2021-09-30 12:16:07Z],
                 "messages" => [
                   %{
                     "from_user_id" => me.id,
                     "to_user_id" => p3.id,
                     "id" => message_id_2,
                     "inserted_at" => datetime(message_id_2),
                     "message" => %{
                       "answer" => "durov",
                       "question" => "telegram",
                       "url" => "https://t.me/durov"
                     },
                     "seen" => false
                   },
                   %{
                     "from_user_id" => p3.id,
                     "to_user_id" => me.id,
                     "id" => message_id_3,
                     "inserted_at" => datetime(message_id_3),
                     "message" => %{
                       "question" => "audio",
                       "s3_key" => "abcd",
                       "url" => "https://d6666.cloudfront.net/abcd"
                     },
                     "seen" => false
                   }
                 ]
               },
               %{
                 "id" => c2.id,
                 "profile" => %{
                   name: "mate-2",
                   story: [],
                   user_id: p2.id,
                   gender: "N",
                   distance: 9510,
                   address: %{
                     "en_US" => %{
                       "city" => "Buenos Aires",
                       "state" => "Autonomous City of Buenos Aires",
                       "country" => "Argentina",
                       "iso_country_code" => "AR"
                     }
                   }
                 },
                 "inserted_at" => ~U[2021-09-30 12:16:06Z],
                 "messages" => [
                   %{
                     "from_user_id" => me.id,
                     "to_user_id" => p2.id,
                     "id" => message_id_1,
                     "inserted_at" => datetime(message_id_1),
                     "message" => %{"question" => "text", "value" => "hey mama"},
                     "seen" => false
                   }
                 ]
               },
               %{
                 "id" => c1.id,
                 "profile" => %{
                   name: "mate-1",
                   story: [],
                   user_id: p1.id,
                   gender: "F",
                   distance: 9510,
                   address: %{
                     "en_US" => %{
                       "city" => "Buenos Aires",
                       "state" => "Autonomous City of Buenos Aires",
                       "country" => "Argentina",
                       "iso_country_code" => "AR"
                     }
                   }
                 },
                 "inserted_at" => ~U[2021-09-30 12:16:05Z],
                 "messages" => []
               }
             ]
    end

    test "with no news", %{socket: socket, me: me} do
      assert {:ok, reply, _socket} = join(socket, "feed:" <> me.id)
      refute reply["news"]
    end

    test "without todos", %{socket: socket, me: me} do
      assert {:ok, reply, _socket} = join(socket, "feed:" <> me.id)
      refute reply["todos"]
    end

    test "with update todo", %{socket_with_old_version: socket_with_old_version, me: me} do
      assert {:ok, %{"todos" => todos}, _socket} = join(socket_with_old_version, "feed:" <> me.id)

      assert [_first_todos_item = %{story: story}] = todos
      assert [p1] = story

      assert %{"background" => %{"color" => _}, "labels" => labels, "size" => _} = p1

      assert labels
             |> Enum.any?(fn label ->
               label["action"] == "update_app"
             end)
    end

    test "with hidden_profile todo", %{socket: socket, me: me} do
      %T.Accounts.Profile{user_id: me.id}
      |> Ecto.Changeset.change(hidden?: true)
      |> T.Repo.update()

      assert {:ok, %{"todos" => todos}, _socket} = join(socket, "feed:" <> me.id)

      assert [_first_todos_item = %{story: story}] = todos
      assert [p1] = story

      assert %{"background" => %{"color" => _}, "labels" => labels, "size" => _} = p1

      assert labels
             |> Enum.any?(fn label ->
               label["action"] == "edit_story"
             end)
    end

    test "in onboarding mode without feed", %{socket: socket, me: me} do
      assert {:ok, reply, _socket} = join(socket, "feed:" <> me.id, %{"onboarding_mode" => true})

      assert reply == %{}
    end

    test "in onboarding mode with feed", %{socket: socket, me: me} do
      assert {:ok, reply, _socket} =
               join(socket, "feed:" <> me.id, %{"onboarding_mode" => true, "need_feed" => true})

      assert reply == %{"feed" => []}
    end
  end

  describe "more" do
    setup :joined

    test "with no data in db", %{socket: socket} do
      ref = push(socket, "more")
      assert_reply(ref, :ok, reply)
      assert reply == %{"feed" => []}
    end

    test "with users who haven't been online for a while", %{socket: socket} do
      long_ago = DateTime.add(DateTime.utc_now(), -182 * 24 * 60 * 60)

      for _ <- 1..3 do
        onboarded_user(
          location: apple_location(),
          accept_genders: ["F", "N", "M"],
          last_active: long_ago
        )
      end

      ref = push(socket, "more")
      assert_reply(ref, :ok, reply)
      assert reply == %{"feed" => []}
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

      ref = push(socket, "more")
      assert_reply(ref, :ok, %{"feed" => feed0})

      initial_feed_ids =
        Enum.map(feed0, fn %{"profile" => profile} ->
          profile.user_id
        end)

      ref = push(socket, "more")

      assert_reply(ref, :ok, %{"feed" => feed1})

      for {p, _} <- feed1 do
        assert p.user_id not in initial_feed_ids
      end
    end

    test "with age filter" do
      me =
        onboarded_user(
          location: moscow_location(),
          gender: "M",
          accept_genders: ["F"],
          min_age: 20,
          max_age: 40
        )

      # so that our onboarded_user is not treated as the first-time user when being served feed
      not_me = insert(:user)
      inserted_at = DateTime.utc_now() |> DateTime.add(-Feeds.feed_limit_period())
      insert(:seen_profile, by_user: me, user: not_me, inserted_at: inserted_at)

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

      ref = push(socket, "more")
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
                   distance: 9510,
                   address: %{
                     "en_US" => %{
                       "city" => "Buenos Aires",
                       "state" => "Autonomous City of Buenos Aires",
                       "country" => "Argentina",
                       "iso_country_code" => "AR"
                     }
                   }
                 }
               }
             ]
    end

    test "with distance filter" do
      me =
        onboarded_user(
          location: moscow_location(),
          gender: "M",
          accept_genders: ["F"],
          distance: 10
        )

      # so that our onboarded_user is not treated as the first-time user when being served feed
      not_me = insert(:user)
      inserted_at = DateTime.utc_now() |> DateTime.add(-Feeds.feed_limit_period())
      insert(:seen_profile, by_user: me, user: not_me, inserted_at: inserted_at)

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

      ref = push(socket, "more")
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
                   distance: 0,
                   address: %{
                     "en_US" => %{
                       "city" => "Buenos Aires",
                       "state" => "Autonomous City of Buenos Aires",
                       "country" => "Argentina",
                       "iso_country_code" => "AR"
                     }
                   }
                 }
               }
             ]

      me =
        onboarded_user(
          location: moscow_location(),
          accept_genders: ["F"],
          distance: 20000
        )

      # so that our onboarded_user is not treated as the first-time user when being served feed
      not_me = insert(:user)
      inserted_at = DateTime.utc_now() |> DateTime.add(-Feeds.feed_limit_period())
      insert(:seen_profile, by_user: me, user: not_me, inserted_at: inserted_at)

      socket = connected_socket(me)

      assert {:ok, _reply, socket} =
               subscribe_and_join(socket, "feed:" <> me.id, %{"mode" => "normal"})

      ref = push(socket, "more", %{"count" => 3})
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
                   distance: 0,
                   address: %{
                     "en_US" => %{
                       "city" => "Buenos Aires",
                       "state" => "Autonomous City of Buenos Aires",
                       "country" => "Argentina",
                       "iso_country_code" => "AR"
                     }
                   }
                 }
               },
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
                   distance: 9510,
                   address: %{
                     "en_US" => %{
                       "city" => "Buenos Aires",
                       "state" => "Autonomous City of Buenos Aires",
                       "country" => "Argentina",
                       "iso_country_code" => "AR"
                     }
                   }
                 }
               }
             ]
    end
  end

  describe "report without chat" do
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

  describe "report with chat" do
    setup :joined

    setup %{me: me} do
      mate = onboarded_user(story: [], location: apple_location(), name: "mate")
      chat = insert(:chat, user_id_1: me.id, user_id_2: mate.id)
      {:ok, mate: mate, chat: chat}
    end

    setup :joined_mate

    test "reports mate and notifies of deleted_chat", %{
      socket: socket,
      mate: mate,
      me: me
    } do
      ref =
        push(socket, "report", %{
          "user_id" => mate.id,
          "reason" => "he don't believe in jesus"
        })

      assert_reply(ref, :ok, _reply)

      # mate gets deleted_chat message
      assert_push("deleted_chat", push)
      assert push == %{"with_user_id" => me.id}

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

  describe "chats" do
    setup :joined

    test "send-message", %{socket: socket} do
      mate = onboarded_user()

      # save normal message
      ref =
        push(socket, "send-message", %{
          "to_user_id" => mate.id,
          "message" => %{"value" => "hello moto", "question" => "text"}
        })

      assert_reply(ref, :ok, _reply)
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

    test "more: private stories are blurred", %{me: me, socket: socket} do
      # so that our onboarded_user is not treated as the first-time user when being served feed
      not_me = insert(:user)
      insert(:seen_profile, by_user: me, user: not_me, inserted_at: DateTime.utc_now())

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

    test "chat match: private story becomes visible", %{me: me, stacy: stacy} do
      Chats.save_message(stacy.id, me.id, %{"question" => "invitation"})
      Chats.save_message(me.id, stacy.id, %{"question" => "acceptance"})

      assert_push("chat_match", %{"profile" => %{story: [public, private]}})
      assert Map.keys(public) == ["background", "labels", "size"]
      assert Map.keys(private) == ["background", "labels", "private", "size"]
      assert %{"private" => true} = private
    end
  end

  defp joined(%{socket: socket, me: me}) do
    assert {:ok, _reply, socket} = subscribe_and_join(socket, "feed:" <> me.id)

    {:ok, socket: socket}
  end

  defp joined_mate(%{mate: mate}) do
    socket = connected_socket(mate)
    {:ok, _reply, socket} = join(socket, "feed:" <> mate.id)
    {:ok, mate_socket: socket}
  end

  defp datetime(<<_::288>> = uuid) do
    datetime(Ecto.Bigflake.UUID.dump!(uuid))
  end

  defp datetime(<<unix::64, _rest::64>>) do
    unix |> DateTime.from_unix!(:millisecond) |> DateTime.truncate(:second)
  end
end
