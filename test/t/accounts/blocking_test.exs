defmodule T.Accounts.BlockingTest do
  use T.DataCase, async: true
  alias T.{Accounts, Feeds, Matches}
  alias T.Accounts.UserReport
  alias T.Matches.Match

  # TODO blocked user can write to us

  # TODO move to reporting test
  describe "report_user/3" do
    setup do
      _admin = T.Repo.insert!(%Accounts.User{id: T.Support.admin_id(), phone_number: "ADMIN"})
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
      assert {:ok, %{match: nil}} = Feeds.like_profile(reporter.id, reported.id)

      assert {:ok, %{match: %Match{id: match_id, alive?: true}}} =
               Feeds.like_profile(reported.id, reporter.id)

      Matches.subscribe_for_match(match_id)

      assert :ok == Accounts.report_user(reporter.id, reported.id, "he show dicky")
      assert_receive {Matches, [:unmatched, ^match_id], user_ids}

      assert reporter.id in user_ids
      assert reported.id in user_ids

      for user_id <- user_ids do
        assert [] == Matches.get_current_matches(user_id)
      end
    end

    test "marks reported user as seen", %{reporter: reporter, reported: reported} do
      assert :ok == Accounts.report_user(reporter.id, reported.id, "he ugly")
      assert_seen(by_user_id: reporter.id, user_id: reported.id)
    end

    test "3 reports block the user", %{reporter: reporter1, reported: reported} do
      reporter2 = onboarded_user()
      reporter3 = onboarded_user()

      :ok = Accounts.report_user(reporter1.id, reported.id, "he bad")
      refute Repo.get!(Accounts.User, reported.id).blocked_at
      assert Repo.get!(Accounts.Profile, reported.id).hidden? == false
      :ok = Accounts.report_user(reporter2.id, reported.id, "he show dicky")
      refute Repo.get!(Accounts.User, reported.id).blocked_at
      assert Repo.get!(Accounts.Profile, reported.id).hidden? == false
      :ok = Accounts.report_user(reporter3.id, reported.id, "he show dicky")
      assert Repo.get!(Accounts.User, reported.id).blocked_at

      # blocked user is hidden
      assert Repo.get!(Accounts.Profile, reported.id).hidden? == true
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

      assert {:ok, %{match: nil}} = Feeds.like_profile(user.id, other.id)

      assert {:ok, %{match: %Match{id: match_id, alive?: true}}} =
               Feeds.like_profile(other.id, user.id)

      Matches.subscribe_for_match(match_id)

      assert :ok == Accounts.block_user(user.id)

      assert_receive {Matches, [:unmatched, ^match_id], user_ids}

      assert user.id in user_ids
      assert other.id in user_ids

      for user_id <- user_ids do
        assert [] == Matches.get_current_matches(user_id)
      end
    end

    test "blocked user is hidden", %{user: user} do
      assert Repo.get!(Accounts.Profile, user.id).hidden? == false
      assert :ok == Accounts.block_user(user.id)
      assert Repo.get!(Accounts.Profile, user.id).hidden? == true
    end
  end
end
