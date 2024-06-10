defmodule Since.Accounts.DeletionTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: Repo

  alias Since.{Accounts, Chats}
  alias Chats.{Chat, Message}

  describe "delete_user/1" do
    setup do
      %{profile: profile} = user = onboarded_user()
      {:ok, user: user, profile: profile}
    end

    test "profile and user are deleted", %{user: user} do
      assert {:ok, %{delete_user: true}} = Accounts.delete_user(user.id, nil)
      refute Repo.get(Accounts.User, user.id)
      refute Repo.get(Accounts.Profile, user.id)
    end

    test "sessions are deleted", %{user: user} do
      assert <<_::32-bytes>> = token = Accounts.generate_user_session_token(user, "mobile")
      assert [%Accounts.UserToken{token: ^token}] = Repo.all(Accounts.UserToken)

      assert {:ok, %{delete_user: true}} = Accounts.delete_user(user.id, "reason")
      assert [] == Repo.all(Accounts.UserToken)
    end

    test "current chat is deleted", %{user: user} do
      p2 = insert(:profile)

      Chats.subscribe_for_user(user.id)
      Chats.subscribe_for_user(p2.user_id)

      assert {:ok, %Message{chat_id: chat_id, inserted_at: inserted_at} = message1} =
               Chats.save_message(p2.user_id, user.id, %{"question" => "invitation"})

      assert_receive {Chats, :chat, chat}
      user_id = user.id
      mate_id = p2.user_id

      assert %Chat{
               id: ^chat_id,
               user_id_1: ^user_id,
               user_id_2: ^mate_id,
               matched: false,
               inserted_at: ^inserted_at,
               messages: [^message1],
               profile: nil
             } = chat

      assert {:ok, %{delete_user: true, delete_chats: [true]}} =
               Accounts.delete_user(user.id, "reason")

      assert_receive {Chats, :deleted_chat, ^user_id}
      assert [] == Chats.list_chats(p2.user_id, default_location())
    end
  end
end
