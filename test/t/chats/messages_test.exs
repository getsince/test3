defmodule T.Chats.MessagesTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: T.Repo

  alias T.Chats
  alias T.Chats.{Chat, Message}

  describe "save_message/3 for invalid chat" do
    setup [:with_profiles]

    @message %{"question" => "text", "value" => "you can get a few more "}

    test "with non-existent chat", %{profiles: [p1, _]} do
      chat = Ecto.UUID.generate()

      assert_raise Ecto.NoResultsError, fn ->
        Chats.save_message(chat, p1.user_id, @message)
      end
    end

    test "with chat we are not part of", %{profiles: [p1, p2]} do
      p3 = insert(:profile, hidden?: false)
      chat = insert(:chat, user_id_1: p1.user_id, user_id_2: p2.user_id)

      assert_raise Ecto.NoResultsError, fn ->
        Chats.save_message(chat.id, p3.user_id, @message)
      end
    end
  end

  describe "save_first_message/3" do
    setup [:with_profiles]

    test "invitation", %{profiles: [p1, p2]} do
      Chats.subscribe_for_user(p1.user_id)
      Chats.subscribe_for_user(p2.user_id)

      # invite from p1 to p2
      assert {:ok, %Chat{}, %Message{} = message} =
               Chats.save_first_message(p2.user_id, p1.user_id, %{"question" => "invitation"})

      from_user_id = p1.user_id
      to_user_id = p2.user_id

      assert %{
               data: %{"question" => "invitation"},
               from_user_id: ^from_user_id,
               to_user_id: ^to_user_id,
               chat_id: chat_id
             } = message

      assert [i1] = Message |> where(chat_id: ^chat_id) |> T.Repo.all()
      assert i1.from_user_id == p1.user_id
      assert i1.to_user_id == p2.user_id
      assert i1.chat_id == chat_id
      assert i1.data == %{"question" => "invitation"}

      assert_received {Chats, :message, ^i1}
      assert_received {Chats, :message, ^i1}
    end
  end

  describe "save_message/3" do
    setup [:with_profiles, :with_chat]

    test "with empty message", %{profiles: [p1, _], chat: chat} do
      assert {:error, %Ecto.Changeset{valid?: false} = changeset} =
               Chats.save_message(chat.id, p1.user_id, %{"" => ""})

      assert errors_on(changeset) == %{message: ["unrecognized message type"]}
    end

    test "with unsupported message", %{profiles: [p1, _], chat: chat} do
      assert {:error, %Ecto.Changeset{valid?: false} = changeset} =
               Chats.save_message(chat.id, p1.user_id, %{"question" => "interests"})

      assert errors_on(changeset) == %{message: ["unsupported message type"]}
    end

    test "message exchange", %{profiles: [p1, p2], chat: chat} do
      chat_id = chat.id

      Chats.subscribe_for_user(p1.user_id)
      Chats.subscribe_for_user(p2.user_id)

      # text message from p1 to p2
      assert {:ok, %Message{} = message} =
               Chats.save_message(chat.id, p1.user_id, %{
                 "question" => "text",
                 "value" => "helloy"
               })

      from_user_id = p1.user_id
      to_user_id = p2.user_id

      assert %{
               data: %{"question" => "text", "value" => "helloy"},
               from_user_id: ^from_user_id,
               to_user_id: ^to_user_id
             } = message

      assert [i1] = Message |> where(chat_id: ^chat_id) |> T.Repo.all()
      assert i1.from_user_id == p1.user_id
      assert i1.to_user_id == p2.user_id
      assert i1.chat_id == chat.id
      assert i1.data == %{"question" => "text", "value" => "helloy"}

      assert_received {Chats, :message, ^i1}
      assert_received {Chats, :message, ^i1}

      # text message from p2 to p1
      assert {:ok, %Message{} = message} =
               Chats.save_message(chat.id, p2.user_id, %{
                 "value" => "W3sicG9pbnRzIfV0=",
                 "question" => "text"
               })

      assert %{
               data: %{"value" => "W3sicG9pbnRzIfV0=", "question" => "text"},
               from_user_id: ^to_user_id
             } = message

      assert [^i1, i2] = Message |> where(chat_id: ^chat_id) |> T.Repo.all()
      assert i2.from_user_id == p2.user_id
      assert i2.to_user_id == p1.user_id
      assert i2.chat_id == chat.id

      assert i2.data == %{"value" => "W3sicG9pbnRzIfV0=", "question" => "text"}

      assert_received {Chats, :message, ^i2}
      assert_received {Chats, :message, ^i2}

      # spotify message from p2 to p1
      assert {:ok, %Message{}} =
               Chats.save_message(chat.id, p2.user_id, %{"question" => "spotify"})
    end
  end

  describe "save_message/3 side-effects" do
    setup [:with_profiles]

    setup %{profiles: [p1, p2]} do
      Chats.subscribe_for_user(p1.user_id)
      Chats.subscribe_for_user(p2.user_id)
    end

    setup [:with_chat, :with_text_message, :with_contact_message]

    test "push notification is scheduled for mate", %{
      profiles: [%{user_id: from_user_id}, %{user_id: to_user_id}],
      chat: %{id: chat_id}
    } do
      assert [
               %Oban.Job{
                 args: %{
                   "chat_id" => ^chat_id,
                   "from_user_id" => ^from_user_id,
                   "to_user_id" => ^to_user_id,
                   "type" => "contact"
                 }
               },
               %Oban.Job{
                 args: %{
                   "chat_id" => ^chat_id,
                   "from_user_id" => ^from_user_id,
                   "to_user_id" => ^to_user_id,
                   "type" => "text"
                 }
               }
             ] = all_enqueued(worker: T.PushNotifications.DispatchJob)
    end

    test "message is broadcast via pubsub to us & mate", %{
      profiles: [_p1, %{user_id: to_user_id}]
    } do
      assert_receive {Chats, :message, %Message{} = message_0}
      assert_receive {Chats, :message, %Message{} = message_1}
      assert message_0 == message_1
      assert message_0.data == %{"question" => "text", "value" => "helloy"}
      assert message_0.to_user_id == to_user_id

      assert_receive {Chats, :message, %Message{} = message_2}
      assert_receive {Chats, :message, %Message{} = message_3}
      assert message_2 == message_3

      assert message_2.data == %{"question" => "telegram"}

      assert message_2.to_user_id == to_user_id
    end
  end

  describe "mark_message_seen/2" do
    setup [:with_profiles, :with_chat, :with_text_message]

    test "marked seen", %{
      profiles: [%{user_id: _from_user_id}, %{user_id: to_user_id}],
      message: %{id: message_id, seen: seen}
    } do
      assert seen == false
      assert Chats.mark_message_seen(to_user_id, message_id) == :ok

      [i] = Message |> where(id: ^message_id) |> T.Repo.all()
      assert i.seen == true
    end

    test "from sender", %{
      profiles: [%{user_id: from_user_id}, %{user_id: _to_user_id}],
      message: %{id: message_id, seen: seen}
    } do
      assert seen == false
      assert Chats.mark_message_seen(from_user_id, message_id) == :error

      [i] = Message |> where(id: ^message_id) |> T.Repo.all()
      assert i.seen == false
    end
  end

  defp with_profiles(_context) do
    {:ok, profiles: insert_list(2, :profile, hidden?: false)}
  end

  defp with_chat(%{profiles: [p1, p2]}) do
    {:ok, chat: insert(:chat, user_id_1: p1.user_id, user_id_2: p2.user_id)}
  end

  defp with_text_message(%{profiles: [p1, _p2], chat: chat}) do
    message = %{"question" => "text", "value" => "helloy"}

    assert {:ok, %Message{} = message} =
             Chats.save_message(
               chat.id,
               p1.user_id,
               message
             )

    {:ok, message: message}
  end

  defp with_contact_message(%{profiles: [p1, _p2], chat: chat}) do
    message = %{"question" => "telegram"}

    assert {:ok, %Message{} = message} =
             Chats.save_message(
               chat.id,
               p1.user_id,
               message
             )

    {:ok, message: message}
  end
end
