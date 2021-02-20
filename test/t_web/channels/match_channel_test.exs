defmodule TWeb.MatchChannelTest do
  use TWeb.ChannelCase
  alias T.{Accounts, Matches}
  alias T.Accounts.User

  setup do
    {:ok, %User{} = user} = Accounts.register_user(%{phone_number: phone_number()})
    {:ok, user: Repo.preload(user, :profile), socket: connected_socket(user)}
  end

  describe "join a match with no messages" do
    setup :create_match

    test "no messages returned duh", %{socket: socket, match: match} do
      assert {:ok, reply, _socket} = subscribe_and_join(socket, "match:" <> match.id, %{})
      assert reply == %{messages: []}
    end
  end

  describe "join a match with messages" do
    setup :create_match

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
    test "a match when we are not in a match", %{socket: socket, user: user} do
      refute Matches.get_current_match(user.id)

      assert {:error, %{reason: "match not found"}} =
               subscribe_and_join(socket, "match:" <> Ecto.UUID.generate(), %{})
    end

    test "a wrong match (we are in a match but this one's not ours)", %{
      socket: socket,
      user: user
    } do
      p2 = insert(:profile, hidden?: true)
      insert(:match, user_id_1: user.id, user_id_2: p2.user_id, alive?: true)

      assert {:error, %{reason: "match not found"}} =
               subscribe_and_join(socket, "match:" <> Ecto.UUID.generate(), %{})
    end
  end

  describe "post message" do
    setup [:create_match, :join_match]

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

    test "post invalid message", %{socket: socket} do
      ref = push(socket, "message", %{"message" => %{"kind" => "text"}})
      assert_reply ref, :error, reply
      assert reply == %{message: %{data: ["can't be blank"]}}
    end
  end

  describe "upload preflight" do
    setup [:create_match, :join_match]

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
    setup [:create_match, :join_match]

    test "it's broadcasted", %{socket: socket} do
      ref = push(socket, "unmatch", %{})
      assert_reply ref, :ok, reply, 1000
      assert reply == %{}
      assert_broadcast "unmatched", broadcast
      assert broadcast == %{}
    end
  end

  describe "presence" do
    setup [:create_match, :join_match]

    test "receives presence_state", %{user: user} do
      assert_push "presence_state", payload
      assert Map.keys(payload) == [user.id]
    end

    defmacrop assert_presence_diff(pattern) do
      quote do
        assert_broadcast "presence_diff", unquote(pattern)
        assert_push "presence_diff", unquote(pattern)
      end
    end

    test "receives prosence_diff on join/leave", %{user: %{id: me_id}, match: match} do
      %{id: mate_id} = mate = Accounts.get_user!(match.user_id_2)

      assert_presence_diff(%{joins: %{^me_id => _}})
      assert_push "presence_state", %{^me_id => _}

      spawn(fn ->
        {:ok, _reply, socket} = mate |> connected_socket() |> join("match:" <> match.id, %{})
        :timer.sleep(100)
        leave(socket)
      end)

      assert_presence_diff(%{joins: %{^mate_id => _}})
      assert_presence_diff(%{leaves: %{^mate_id => _}})
      refute_receive _anything_else
    end
  end

  defp create_match(%{user: user}) do
    p2 = insert(:profile, hidden?: false)
    {:ok, match: create_match(user.id, p2.user_id)}
  end

  defp create_match(u1, u2) do
    insert(:match, user_id_1: u1, user_id_2: u2, alive?: true)
  end

  defp join_match(%{socket: socket, match: match}) do
    assert {:ok, _reply, socket} = subscribe_and_join(socket, "match:" <> match.id, %{})
    {:ok, socket: socket}
  end
end
