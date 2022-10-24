defmodule T.Accounts.BlockingTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: Repo
  alias T.{Accounts, Matches, Chats}
  alias T.Accounts.UserReport
  alias T.Matches.Match
  alias T.Chats.{Chat, Message}

  # TODO move to reporting test
  describe "report_user/3" do
    setup do
      reporter = onboarded_user()
      reported = onboarded_user()
      {:ok, reporter: reporter, reported: reported}
    end

    test "saves report", %{reporter: reporter, reported: reported} do
      assert :ok == Accounts.report_user(reporter.id, reported.id, "he bad")
      assert [%UserReport{} = report] = Repo.all(UserReport)
      assert report.reason == "he bad"
      assert report.from_user_id == reporter.id
      assert report.on_user_id == reported.id
    end

    test "unmatches if there is a match", %{reporter: reporter, reported: reported} do
      Matches.subscribe_for_user(reporter.id)
      Matches.subscribe_for_user(reported.id)

      assert {:ok, %{match: nil}} =
               Matches.like_user(reporter.id, reported.id, default_location())

      assert {:ok, %{match: %Match{id: match_id, inserted_at: inserted_at}}} =
               Matches.like_user(reported.id, reporter.id, default_location())

      expiration_date =
        inserted_at
        |> DateTime.from_naive!("Etc/UTC")
        |> DateTime.add(Matches.match_ttl())

      # notification for reporter
      assert_receive {Matches, :matched, match}

      assert match == %{
               id: match_id,
               mate: reported.id,
               expiration_date: expiration_date,
               inserted_at: inserted_at
             }

      assert :ok == Accounts.report_user(reporter.id, reported.id, "he show dicky")
      assert_receive {Matches, :unmatched, ^match_id}

      assert [] == Matches.list_matches(reported.id, default_location())
      assert [] == Matches.list_matches(reporter.id, default_location())
    end

    test "deletes chat if there is a chat", %{reporter: reporter, reported: reported} do
      Chats.subscribe_for_user(reporter.id)
      Chats.subscribe_for_user(reported.id)

      assert {:ok, %Message{}} =
               Chats.save_message(reported.id, reporter.id, %{"question" => "invitation"})

      assert {:ok, %Message{}} =
               Chats.save_message(reporter.id, reported.id, %{"question" => "acceptance"})

      assert_receive {Chats, :chat, %Chat{}}
      assert_receive {Chats, :chat, %Chat{}}

      assert_receive {Chats, :message, %Message{}}
      assert_receive {Chats, :message, %Message{}}

      assert :ok == Accounts.report_user(reporter.id, reported.id, "he show dicky")
      reporter_id = reporter.id
      # reported receives push about deleted_chat with reporter
      assert_receive {Chats, :deleted_chat, ^reporter_id}

      assert [] == Chats.list_chats(reported.id, default_location())
      assert [] == Chats.list_chats(reporter.id, default_location())
    end
  end

  describe "block_user/1" do
    setup do
      {:ok, user: onboarded_user()}
    end

    test "blocks the user", %{user: user} do
      refute Repo.get!(Accounts.User, user.id).blocked_at
      assert :ok == Accounts.block_user(user.id)
      assert Repo.get!(Accounts.User, user.id).blocked_at
    end

    test "unmatches if there is a match", %{user: user} do
      other = onboarded_user()

      assert {:ok, %{match: nil}} = Matches.like_user(user.id, other.id, default_location())

      assert {:ok, %{match: %Match{id: match_id}}} =
               Matches.like_user(other.id, user.id, default_location())

      Matches.subscribe_for_user(user.id)
      Matches.subscribe_for_user(other.id)

      assert :ok == Accounts.block_user(user.id)

      assert_receive {Matches, :unmatched, ^match_id}

      assert [] == Matches.list_matches(user.id, default_location())
      assert [] == Matches.list_matches(other.id, default_location())
    end

    test "deletes chats if there are chats", %{user: user} do
      other = onboarded_user()

      assert {:ok, %Message{}} =
               Chats.save_message(other.id, user.id, %{"question" => "invitation"})

      Chats.subscribe_for_user(user.id)
      Chats.subscribe_for_user(other.id)

      assert :ok == Accounts.block_user(user.id)

      user_id = user.id
      assert_receive {Chats, :deleted_chat, ^user_id}

      assert [] == Chats.list_chats(user.id, default_location())
      assert [] == Chats.list_chats(other.id, default_location())
    end

    test "blocked user is hidden", %{user: user} do
      assert Repo.get!(Accounts.Profile, user.id).hidden? == false
      assert :ok == Accounts.block_user(user.id)
      assert Repo.get!(Accounts.Profile, user.id).hidden? == true
    end
  end
end
