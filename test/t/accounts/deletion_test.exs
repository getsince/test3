defmodule T.Accounts.DeletionTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: Repo

  alias T.{Accounts, Feeds, Matches}
  alias Matches.Match

  describe "delete_user/1" do
    setup do
      %{profile: profile} = user = onboarded_user()
      {:ok, user: user, profile: profile}
    end

    test "profile and user are deleted", %{user: user} do
      assert {:ok, %{delete_user: true, unmatch: []}} = Accounts.delete_user(user.id)
      refute Repo.get(Accounts.User, user.id)
      refute Repo.get(Accounts.Profile, user.id)
    end

    test "sessions are deleted", %{user: user} do
      assert <<_::32-bytes>> = token = Accounts.generate_user_session_token(user, "mobile")
      assert [%Accounts.UserToken{token: ^token}] = Repo.all(Accounts.UserToken)

      assert {:ok, %{delete_user: true, unmatch: []}} = Accounts.delete_user(user.id)
      assert [] == Repo.all(Accounts.UserToken)
    end

    test "current match is unmatched", %{user: user} do
      p2 = insert(:profile)

      Matches.subscribe_for_user(user.id)
      Matches.subscribe_for_user(p2.user_id)

      assert {:ok, %{match: nil}} = Feeds.like_profile(p2.user_id, user.id)
      assert {:ok, %{match: %Match{id: match_id}}} = Feeds.like_profile(user.id, p2.user_id)

      assert_receive {Matches, [:matched, ^match_id], [_, _] = user_ids}
      assert_receive {Matches, [:matched, ^match_id], ^user_ids}

      Matches.subscribe_for_match(match_id)

      assert {:ok,
              %{
                delete_user: true,
                unmatch: [ok: ^user_ids]
              }} = Accounts.delete_user(user.id)

      assert_receive {Matches, [:unmatched, ^match_id], ^user_ids}
    end
  end
end
