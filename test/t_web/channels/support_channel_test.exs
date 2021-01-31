defmodule TWeb.SupportChannelTest do
  use TWeb.ChannelCase, async: true
  alias T.{Accounts, Support}
  alias T.Accounts.User

  setup do
    {:ok, %User{} = user} = Accounts.register_user(%{phone_number: phone_number()})
    {:ok, user: Repo.preload(user, :profile), socket: connected_socket(user)}
  end

  describe "join a support channel with no messages" do
    test "no messages returned duh", %{socket: socket, user: user} do
      assert {:ok, reply, _socket} = subscribe_and_join(socket, "support:" <> user.id, %{})
      assert reply == %{messages: []}
    end
  end

  describe "join a channel with messages" do
    setup %{user: user} do
      messages =
        for text <- ["hey", "i have problemas", "nobody likes me"] do
          {:ok, message} =
            Support.add_message(user.id, user.id, %{
              "kind" => "text",
              "data" => %{"text" => text}
            })

          message
        end

      {:ok, messages: messages}
    end

    test "but we don't provide last_message_id", %{
      socket: socket,
      user: user,
      messages: [m1, m2, m3]
    } do
      assert {:ok, reply, _socket} = subscribe_and_join(socket, "support:" <> user.id, %{})

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
                   data: %{"text" => "i have problemas"},
                   id: m2.id,
                   kind: "text",
                   timestamp: DateTime.from_naive!(m2.inserted_at, "Etc/UTC")
                 },
                 %{
                   author_id: user.id,
                   data: %{"text" => "nobody likes me"},
                   id: m3.id,
                   kind: "text",
                   timestamp: DateTime.from_naive!(m3.inserted_at, "Etc/UTC")
                 }
               ]
             }
    end

    test "we provide last_message_id", %{
      socket: socket,
      user: user,
      messages: [_m1, m2, m3]
    } do
      assert {:ok, reply, _socket} =
               subscribe_and_join(socket, "support:" <> user.id, %{"last_message_id" => m2.id})

      assert reply == %{
               messages: [
                 %{
                   author_id: user.id,
                   data: %{"text" => "nobody likes me"},
                   id: m3.id,
                   kind: "text",
                   timestamp: DateTime.from_naive!(m3.inserted_at, "Etc/UTC")
                 }
               ]
             }
    end
  end

  describe "wrong join" do
    @tag skip: true
    test "for a channel for different user", %{socket: socket} do
      assert {:error, %{reason: "match not found"}} =
               subscribe_and_join(socket, "support:" <> Ecto.UUID.generate(), %{})
    end
  end

  describe "post message" do
    setup :join_support

    test "it gets broadcasted", %{socket: socket, user: user} do
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

      [%{id: id, inserted_at: inserted_at}] = Support.list_messages(user.id)

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
    setup :join_support

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

  defp join_support(%{socket: socket, user: user}) do
    assert {:ok, _reply, socket} = subscribe_and_join(socket, "support:" <> user.id, %{})
    {:ok, socket: socket}
  end
end
