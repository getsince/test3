defmodule Since.ChatsTest do
  use Since.DataCase, async: true
  use Oban.Testing, repo: Repo

  alias Since.{Chats, PushNotifications.DispatchJob}
  alias Since.Feeds.FeedProfile
  alias Since.Chats.{Chat, Message}

  describe "delete_chat/2" do
    test "chat no longer, deleted_chat broadcasted" do
      [%{user_id: p1_id}, %{user_id: p2_id}] = insert_list(2, :profile, hidden?: false)

      Chats.subscribe_for_user(p1_id)
      Chats.subscribe_for_user(p2_id)

      parent = self()

      spawn(fn ->
        Chats.subscribe_for_user(p1_id)
        Chats.subscribe_for_user(p2_id)

        Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())

        assert {:ok, %Message{}} = Chats.save_message(p2_id, p1_id, %{"question" => "invitation"})
      end)

      assert_receive {Chats, :chat, _chat}
      assert_receive {Chats, :chat, chat}
      assert %{id: chat_id, messages: [message]} = chat
      assert %{id: invite_id, from_user_id: from_user_id} = message
      assert from_user_id == p1_id

      assert {:ok, %Message{id: acceptance_id}} =
               Chats.save_message(p1_id, p2_id, %{"question" => "acceptance"})

      # for p1
      assert_receive {Chats, :message, %{chat_id: ^chat_id, from_user_id: ^p2_id}}
      assert_receive {Chats, :message, %{chat_id: ^chat_id, from_user_id: ^p2_id}}

      user_ids = Enum.sort([p1_id, p2_id])
      assert_receive {Chats, :chat_match, ^user_ids}
      assert_receive {Chats, :chat_match, ^user_ids}

      assert [%Chat{id: ^chat_id, profile: %FeedProfile{user_id: ^p2_id}}] =
               Chats.list_chats(p1_id, default_location())

      assert [%Chat{id: ^chat_id, profile: %FeedProfile{user_id: ^p1_id}}] =
               Chats.list_chats(p2_id, default_location())

      spawn(fn ->
        Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())
        assert true == Chats.delete_chat(p1_id, p2_id)
      end)

      # for p1
      assert_receive {Chats, :deleted_chat, ^p2_id}
      # for p2
      assert_receive {Chats, :deleted_chat, ^p1_id}

      assert [] == Chats.list_chats(p1_id, default_location())
      assert [] == Chats.list_chats(p2_id, default_location())

      expected = [
        %{
          "from_user_id" => p2_id,
          "type" => "acceptance",
          "to_user_id" => p1_id,
          "chat_id" => chat_id,
          "message_id" => acceptance_id,
          "data" => %{"question" => "acceptance"}
        },
        %{
          "from_user_id" => p1_id,
          "type" => "invitation",
          "to_user_id" => p2_id,
          "chat_id" => chat_id,
          "message_id" => invite_id,
          "data" => %{"question" => "invitation"}
        }
      ]

      actual = Enum.map(all_enqueued(worker: DispatchJob), fn job -> job.args end)

      assert_lists_equal(expected, actual)
    end
  end
end
