defmodule TWeb.FeedChanneLiveTest do
  use TWeb.ChannelCase, async: true

  alias T.{Accounts, Calls, Matches, Feeds}
  alias Matches.Match
  alias Calls.Call

  import Mox
  setup :verify_on_exit!

  setup do
    me = onboarded_user(location: moscow_location(), accept_genders: ["F", "N", "M"])
    {:ok, me: me, socket: connected_socket(me)}
  end

  describe "join" do
    test "with matches", %{socket: socket, me: me} do
      [p1, p2, p3] = [
        onboarded_user(story: [], name: "mate-1", location: apple_location(), gender: "F"),
        onboarded_user(story: [], name: "mate-2", location: apple_location(), gender: "N"),
        onboarded_user(story: [], name: "mate-3", location: apple_location(), gender: "M")
      ]

      [m1, m2, _m3] = [
        insert(:match, user_id_1: me.id, user_id_2: p1.id, inserted_at: ~N[2021-09-30 12:16:05]),
        insert(:match, user_id_1: me.id, user_id_2: p2.id, inserted_at: ~N[2021-09-30 12:16:06]),
        insert(:match, user_id_1: me.id, user_id_2: p3.id, inserted_at: ~N[2021-09-30 12:16:07])
      ]

      joined_mate(%{mate: p1})
      joined_mate(%{mate: p2})

      assert {:ok, %{"matches" => matches}, _socket} =
               join(socket, "feed:" <> me.id, %{"mode" => "live"})

      assert matches == [
               %{
                 "id" => m2.id,
                 "profile" => %{name: "mate-2", story: [], user_id: p2.id, gender: "N"}
               },
               %{
                 "id" => m1.id,
                 "profile" => %{name: "mate-1", story: [], user_id: p1.id, gender: "F"}
               }
             ]
    end

    test "with invites", %{socket: socket, me: me} do
      mate = onboarded_user(story: [], name: "mate", location: apple_location(), gender: "F")

      joined_mate(%{mate: mate})
      assert {:ok, _reply, _socket} = join(socket, "feed:" <> me.id, %{"mode" => "live"})

      Feeds.live_invite_user(mate.id, me.id)

      assert {:ok, reply, _socket} = join(socket, "feed:" <> me.id, %{"mode" => "live"})
      expiration_date = session_expiration_date()

      assert reply == %{
               "mode" => "live",
               "session_expiration_date" => expiration_date,
               "live_session_duration" => 7200,
               "invites" => [
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

    test "with archive match", %{socket: socket, me: me} do
      p1 = onboarded_user(story: [], name: "mate-1", location: apple_location(), gender: "F")

      m1 =
        insert(:match, user_id_1: me.id, user_id_2: p1.id, inserted_at: ~N[2021-09-30 12:16:05])

      joined_mate(%{mate: p1})

      assert {:ok, %{"matches" => matches}, socket} =
               join(socket, "feed:" <> me.id, %{"mode" => "live"})

      assert matches == [
               %{
                 "id" => m1.id,
                 "profile" => %{name: "mate-1", story: [], user_id: p1.id, gender: "F"}
               }
             ]

      push(socket, "archive-match", %{"match_id" => m1.id})

      assert {:ok, %{"matches" => matches}, _socket} =
               join(socket, "feed:" <> me.id, %{"mode" => "live"})

      assert matches == [
               %{
                 "id" => m1.id,
                 "profile" => %{name: "mate-1", story: [], user_id: p1.id, gender: "F"}
               }
             ]
    end

    test "with missed calls", %{socket: socket, me: me} do
      mate = onboarded_user(story: [], location: apple_location(), name: "mate", gender: "F")

      _match = insert(:match, user_id_1: me.id, user_id_2: mate.id)

      expiration_date = session_expiration_date()

      call =
        insert(:call,
          called: me,
          caller: mate,
          inserted_at: expiration_date,
          ended_at: expiration_date
        )

      assert {:ok, reply, _socket} = join(socket, "feed:" <> me.id, %{"mode" => "live"})

      assert reply == %{
               "mode" => "live",
               "session_expiration_date" => expiration_date,
               "live_session_duration" => 7200,
               "missed_calls" => [
                 %{
                   "call" => %{
                     "id" => call.id,
                     "started_at" => DateTime.from_naive!(call.inserted_at, "Etc/UTC"),
                     "ended_at" => DateTime.from_naive!(call.ended_at, "Etc/UTC")
                   },
                   "profile" => %{name: "mate", story: [], user_id: mate.id, gender: "F"}
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

    test "with active users more than count", %{socket: socket} do
      now = DateTime.utc_now()

      [m1, m2, m3] = [
        onboarded_user(
          name: "mate-1",
          location: apple_location(),
          story: [%{"background" => %{"s3_key" => "test"}, "labels" => []}],
          gender: "F",
          accept_genders: ["M"],
          last_active: DateTime.add(now, -1),
          like_ratio: 1.0
        ),
        onboarded_user(
          name: "mate-2",
          location: apple_location(),
          story: [%{"background" => %{"s3_key" => "test"}, "labels" => []}],
          gender: "N",
          accept_genders: ["M"],
          last_active: DateTime.add(now, -2),
          like_ratio: 0.5
        ),
        onboarded_user(
          name: "mate-3",
          location: apple_location(),
          story: [%{"background" => %{"s3_key" => "test"}, "labels" => []}],
          gender: "M",
          accept_genders: ["M"],
          last_active: DateTime.add(now, -3),
          like_ratio: 0
        )
      ]

      joined_mate(%{mate: m1})
      joined_mate(%{mate: m2})
      joined_mate(%{mate: m3})

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

    test "seen profiles are returned in feed", %{socket: socket, me: me} do
      mate =
        onboarded_user(
          name: "mate",
          location: apple_location(),
          story: [%{"background" => %{"s3_key" => "test"}, "labels" => []}],
          gender: "M",
          accept_genders: ["M"]
        )

      joined_mate(%{mate: mate})

      T.Repo.insert(%T.Feeds.SeenProfile{by_user_id: me.id, user_id: mate.id})

      ref = push(socket, "more", %{"count" => 5})
      assert_reply(ref, :ok, %{"cursor" => _cursor, "feed" => feed})
      assert length(feed) == 1
    end
  end

  describe "live-invite" do
    setup :joined

    setup do
      {:ok, mate: onboarded_user(story: [], location: apple_location(), name: "mate")}
    end

    setup :joined_mate

    test "normal", %{
      me: me,
      mate: mate,
      mate_socket: mate_socket
    } do
      # mate likes us
      ref = push(mate_socket, "live-invite", %{"user_id" => me.id})
      assert_reply(ref, :ok, reply)
      assert reply == %{}

      # we got notified of like
      assert_push("live_invite", invite)

      assert invite == %{
               "profile" => %{
                 gender: "M",
                 name: "mate",
                 story: [],
                 user_id: mate.id
               }
             }
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

    test "when non-matched with mate", %{me: me, mate: mate, socket: socket} do
      if Feeds.is_now_live_mode() do
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

  defp joined(%{socket: socket, me: me}) do
    assert {:ok, _reply, socket} =
             subscribe_and_join(socket, "feed:" <> me.id, %{"mode" => "live"})

    {:ok, socket: socket}
  end

  defp joined_mate(%{mate: mate}) do
    socket = connected_socket(mate)
    {:ok, _reply, socket} = join(socket, "feed:" <> mate.id, %{"mode" => "live"})
    {:ok, mate_socket: socket}
  end

  defp session_expiration_date() do
    {_start_date, end_date} = Feeds.live_mode_start_and_end_dates()
    end_date
  end
end
