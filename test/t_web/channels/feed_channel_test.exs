defmodule TWeb.FeedChannelTest do
  use TWeb.ChannelCase
  alias T.Feeds

  setup do
    me = onboarded_user()
    {:ok, me: me, socket: connected_socket(me)}
  end

  describe "join" do
    test "returns nil current session if there none", %{socket: socket, me: me} do
      assert {:ok, reply, _socket} = join(socket, "feed:" <> me.id)
      assert reply == %{"current_session" => nil}
    end

    @reference ~U[2021-07-21 11:55:18.941048Z]

    test "returns current session if there is one", %{socket: socket, me: me} do
      %{flake: id} = Feeds.activate_session(me.id, _duration = 60, @reference)
      assert {:ok, reply, _socket} = join(socket, "feed:" <> me.id)
      assert reply == %{"current_session" => %{id: id, expires_at: ~U[2021-07-21 12:55:18Z]}}
    end
  end

  describe "activate-session" do
    setup :joined

    test "creates new session", %{socket: socket, me: me} do
      ref = push(socket, "activate-session", %{"duration" => 60})
      assert_reply ref, :ok
      assert Feeds.get_current_session(me.id)
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
                 session: %{
                   id: s1,
                   expires_at: ~U[2021-07-21 12:55:18Z]
                 },
                 profile: %{
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
                 session: %{
                   id: s2,
                   expires_at: ~U[2021-07-21 12:55:18Z]
                 },
                 profile: %{
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
                 session: %{
                   id: s3,
                   expires_at: ~U[2021-07-21 12:55:18Z]
                 },
                 profile: %{
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
               "feed_item" => %{
                 session: %{
                   id: s1,
                   expires_at: ~U[2021-07-21 12:55:18Z]
                 },
                 profile: %{
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
             }

      assert_push "activated", push

      assert push == %{
               "feed_item" => %{
                 session: %{
                   id: s2,
                   expires_at: ~U[2021-07-21 12:55:18Z]
                 },
                 profile: %{
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
             }

      assert_push "invite", push

      assert push == %{
               "feed_item" => %{
                 session: %{
                   id: s2,
                   expires_at: ~U[2021-07-21 12:55:18Z]
                 },
                 profile: %{
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
             }

      refute_receive _anything_else

      ref = push(socket, "invites")
      assert_reply ref, :ok, reply

      assert reply == %{
               "invites" => [
                 %{
                   session: %{
                     id: s2,
                     expires_at: ~U[2021-07-21 12:55:18Z]
                   },
                   profile: %{
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

  defp joined(%{socket: socket, me: me}) do
    assert {:ok, _reply, socket} = subscribe_and_join(socket, "feed:" <> me.id)
    {:ok, socket: socket}
  end
end
