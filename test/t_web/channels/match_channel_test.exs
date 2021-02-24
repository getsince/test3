defmodule TWeb.MatchChannelTest do
  use TWeb.ChannelCase
  alias T.{Accounts, Matches, Feeds}

  setup do
    me = onboarded_user()
    {:ok, me: me, socket: connected_socket(me)}
  end

  describe "join with no matches" do
    test "no matches returned duh, and presence state is empty", %{socket: socket, me: me} do
      assert {:ok, reply, _socket} = subscribe_and_join(socket, "matches:" <> me.id, %{})
      assert reply == %{matches: []}
      assert_push "presence_state", push
      assert push == %{}
    end
  end

  defp render_match(match, online? \\ false) do
    %{
      id: match.id,
      online: online?,
      profile: %{
        birthdate: nil,
        city: nil,
        first_date_idea: nil,
        free_form: nil,
        gender: "F",
        height: nil,
        interests: [],
        job: nil,
        major: nil,
        most_important_in_life: nil,
        name: nil,
        occupation: nil,
        photos: [],
        song: nil,
        tastes: %{},
        university: nil,
        user_id: match.user_id_2
      }
    }
  end

  describe "join with matches" do
    setup %{me: me} do
      [p1, p2] = insert_list(2, :profile, gender: "F")
      assert {:ok, %{match: nil}} = Feeds.like_profile(me.id, p1.user_id)
      assert {:ok, %{match: m1}} = Feeds.like_profile(p1.user_id, me.id)

      assert {:ok, %{match: nil}} = Feeds.like_profile(p2.user_id, me.id)
      assert {:ok, %{match: m2}} = Feeds.like_profile(me.id, p2.user_id)

      {:ok, matches: [m1, m2]}
    end

    test "mathces returned, and presence state is pushed as well", %{
      matches: [m1, m2],
      socket: socket,
      me: me
    } do
      assert {:ok, %{matches: matches}, _socket} =
               subscribe_and_join(socket, "matches:" <> me.id, %{})

      assert render_match(m1) in matches
      assert render_match(m2) in matches
      assert length(matches) == 2

      assert_push "presence_state", push
      assert push == %{}
    end
  end

  describe "join with voice mail" do
    setup %{user: user, match: match} do
      messages =
        for text <- ["hey", "hoi", "let's go"] do
          {:ok, message} =
            Matches.add_message(match.id, user.id, %{
              "kind" => "text",
              "data" => %{"text" => text}
            })

          message
        end

      {:ok, match: match, messages: messages}
    end

    @tag skip: true
    test "a match with some messages but we don't provide last_message_id", %{
      socket: socket,
      match: match,
      user: user,
      messages: [m1, m2, m3]
    } do
      assert {:ok, reply, _socket} = subscribe_and_join(socket, "match:" <> match.id, %{})

      assert reply == %{
               messages: [
                 %{
                   author_id: user.id,
                   data: %{"text" => "hey"},
                   id: m1.id,
                   kind: "text",
                   timestamp: DateTime.from_naive!(m1.inserted_at, "Etc/UTC")
                 },
                 %{
                   author_id: user.id,
                   data: %{"text" => "hoi"},
                   id: m2.id,
                   kind: "text",
                   timestamp: DateTime.from_naive!(m2.inserted_at, "Etc/UTC")
                 },
                 %{
                   author_id: user.id,
                   data: %{"text" => "let's go"},
                   id: m3.id,
                   kind: "text",
                   timestamp: DateTime.from_naive!(m3.inserted_at, "Etc/UTC")
                 }
               ]
             }
    end

    @tag skip: true
    test "a match with some messages and we provide last_message_id", %{
      socket: socket,
      match: match,
      user: user,
      messages: [_m1, m2, m3]
    } do
      assert {:ok, reply, _socket} =
               subscribe_and_join(socket, "match:" <> match.id, %{"last_message_id" => m2.id})

      assert reply == %{
               messages: [
                 %{
                   author_id: user.id,
                   data: %{"text" => "let's go"},
                   id: m3.id,
                   kind: "text",
                   timestamp: DateTime.from_naive!(m3.inserted_at, "Etc/UTC")
                 }
               ]
             }
    end
  end

  describe "wrong join" do
    # TODO capture log?
    @tag skip: true
    test "a wrong user id", %{socket: socket} do
      assert {:error, %{reason: "join crashed"}} =
               subscribe_and_join(socket, "matches:" <> Ecto.UUID.generate(), %{})
    end
  end

  describe "post message" do
    setup :subscribe_and_join

    @tag skip: true
    test "it gets broadcasted (once)", %{socket: socket, user: user, match: match} do
      ref =
        push(socket, "message", %{
          "message" => %{
            "kind" => "text",
            "data" => %{"text" => "hey"}
          }
        })

      assert_reply ref, :ok, reply
      assert reply == %{}
      assert_broadcast "message:new", broadcast

      [%{id: id, inserted_at: inserted_at}] = Matches.list_messages(match.id)

      assert broadcast == %{
               message: %{
                 author_id: user.id,
                 data: %{"text" => "hey"},
                 id: id,
                 kind: "text",
                 timestamp: DateTime.from_naive!(inserted_at, "Etc/UTC")
               }
             }
    end

    @tag skip: true
    test "post invalid message", %{socket: socket} do
      ref = push(socket, "message", %{"message" => %{"kind" => "text"}})
      assert_reply ref, :error, reply
      assert reply == %{message: %{data: ["can't be blank"]}}
    end
  end

  describe "upload preflight" do
    setup :subscribe_and_join

    @tag skip: true
    test "it kinda works, but not sure", %{socket: socket} do
      ref = push(socket, "upload-preflight", %{"media" => %{"content-type" => "audio/aac"}})
      assert_reply ref, :ok, reply

      assert %{
               fields: %{
                 "acl" => "public-read",
                 "content-type" => "audio/aac",
                 "key" => key,
                 "policy" => _policy,
                 "x-amz-algorithm" => "AWS4-HMAC-SHA256",
                 # "AWS_ACCESS_KEY_ID/20210116/eu-central-1/s3/aws4_request",
                 "x-amz-credential" => _creds,
                 # "20210116T005301Z",
                 "x-amz-date" => _date,
                 "x-amz-server-side-encryption" => "AES256",
                 # "5261439017fa0c08b0c6119e2f6228eb0a2918d8d81a759cb879a4934f353bdf"
                 "x-amz-signature" => _signature
               },
               key: key,
               url: "https://pretend-this-is-real.s3.amazonaws.com"
             } = reply
    end
  end

  describe "unmatch" do
    setup :subscribe_and_join

    setup %{me: me} do
      assert_push "presence_state", %{}

      [p1] = insert_list(1, :profile, gender: "F")

      assert {:ok, %{match: nil}} = Feeds.like_profile(me.id, p1.user_id)
      assert {:ok, %{match: m1}} = Feeds.like_profile(p1.user_id, me.id)

      assert_push "matched", _

      {:ok, match: m1}
    end

    test "it's broadcasted", %{socket: socket, match: match} do
      ref = push(socket, "unmatch", %{"match_id" => match.id})
      assert_reply ref, :ok, reply, 1000
      assert reply == %{}

      assert_push "unmatched", push
      assert push == %{id: match.id}

      refute_receive _anything
    end
  end

  describe "presence" do
    setup :subscribe_and_join

    setup %{me: me} do
      assert_push "presence_state", %{}

      [p1] = insert_list(1, :profile, gender: "F")

      assert {:ok, %{match: nil}} = Feeds.like_profile(me.id, p1.user_id)
      assert {:ok, %{match: m1}} = Feeds.like_profile(p1.user_id, me.id)

      assert_push "matched", _

      {:ok, match: m1}
    end

    test "receives prosence_diff on mates join/leave", %{match: %{id: match_id} = match} do
      %{id: mate_id} = mate = Accounts.get_user!(match.user_id_2)

      spawn(fn ->
        {:ok, reply, socket} = mate |> connected_socket() |> join("matches:" <> mate.id, %{})
        assert %{matches: [%{id: ^match_id, online: true}]} = reply
        :timer.sleep(10)
        leave(socket)
      end)

      assert_presence_diff(%{joins: %{^mate_id => _}})
      assert_presence_diff(%{leaves: %{^mate_id => _}})
      refute_receive _anything_else
    end
  end

  defp subscribe_and_join(%{socket: socket, me: me}) do
    assert {:ok, _reply, socket} = subscribe_and_join(socket, "matches:" <> me.id, %{})
    {:ok, socket: socket}
  end
end
