defmodule T.Accounts.DeletionTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: Repo

  alias T.{Accounts, Matches}
  alias Matches.Match

  @match_expiration_duration 172_800

  describe "delete_user/1" do
    setup do
      %{profile: profile} = user = onboarded_user()
      {:ok, user: user, profile: profile}
    end

    test "profile and user are deleted", %{user: user} do
      assert {:ok, %{delete_user: true}} = Accounts.delete_user(user.id)
      refute Repo.get(Accounts.User, user.id)
      refute Repo.get(Accounts.Profile, user.id)
    end

    test "sessions are deleted", %{user: user} do
      assert <<_::32-bytes>> = token = Accounts.generate_user_session_token(user, "mobile")
      assert [%Accounts.UserToken{token: ^token}] = Repo.all(Accounts.UserToken)

      assert {:ok, %{delete_user: true}} = Accounts.delete_user(user.id)
      assert [] == Repo.all(Accounts.UserToken)
    end

    test "current match is unmatched", %{user: user} do
      p2 = insert(:profile)

      Matches.subscribe_for_user(user.id)
      Matches.subscribe_for_user(p2.user_id)

      assert {:ok, %{match: nil}} = Matches.like_user(p2.user_id, user.id)
      assert {:ok, %{match: %Match{id: match_id}}} = Matches.like_user(user.id, p2.user_id)

      exp_date = expiration_date()

      assert_receive {Matches, :matched, match}
      assert match == %{id: match_id, mate: user.id, expiration_date: exp_date}

      assert {:ok, %{delete_user: true, unmatch: [true]}} = Accounts.delete_user(user.id)
      assert_receive {Matches, :unmatched, ^match_id}
      assert [] == Matches.list_matches(p2.user_id)
    end
  end

  defp expiration_date() do
    DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(@match_expiration_duration)
  end
end
