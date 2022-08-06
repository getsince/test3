defmodule T.Accounts.BlockingTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: Repo
  alias T.{Accounts, Matches}
  alias T.Accounts.UserReport
  alias T.Matches.Match

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

    test "blocked user is hidden", %{user: user} do
      assert Repo.get!(Accounts.Profile, user.id).hidden? == false
      assert :ok == Accounts.block_user(user.id)
      assert Repo.get!(Accounts.Profile, user.id).hidden? == true
    end
  end
end
