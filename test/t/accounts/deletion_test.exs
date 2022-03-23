defmodule T.Accounts.DeletionTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: Repo

  alias T.{Accounts, Matches}
  alias Matches.Match

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

      assert {:ok, %{match: nil}} = Matches.like_user(p2.user_id, user.id, default_location())

      assert {:ok, %{match: %Match{id: match_id, inserted_at: inserted_at}}} =
               Matches.like_user(user.id, p2.user_id, default_location())

      expiration_date =
        inserted_at
        |> DateTime.from_naive!("Etc/UTC")
        |> DateTime.add(Matches.match_ttl())

      assert_receive {Matches, :matched, match}
      user_id = user.id

      assert match == %{
               id: match_id,
               mate: user_id,
               expiration_date: expiration_date,
               inserted_at: inserted_at
             }

      assert {:ok, %{delete_user: true, unmatch: [true]}} = Accounts.delete_user(user.id)
      assert_receive {Matches, :unmatched, ^match_id}
      assert [] == Matches.list_matches(p2.user_id, default_location())
    end
  end
end
