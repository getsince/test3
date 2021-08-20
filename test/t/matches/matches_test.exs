defmodule T.MatchesTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: T.Repo
  alias T.{Matches, Feeds, Accounts.Profile}
  alias Matches.Match

  describe "unmatch" do
    @tag skip: true
    test "match no longer, likes no longer, unmatched broadcasted" do
      [%{user_id: p1_id} = p1, %{user_id: p2_id} = p2] = insert_list(2, :profile, hidden?: false)

      assert {:ok, %{match: nil}} = Feeds.like_profile(p1_id, p2_id)

      assert [] == Feeds.all_profile_likes_with_liker_profile(p1_id)

      assert [%Feeds.ProfileLike{by_user_id: ^p1_id, user_id: ^p2_id}] =
               Feeds.all_profile_likes_with_liker_profile(p2_id)

      assert {:ok, %{match: %Match{id: match_id}}} = Feeds.like_profile(p2_id, p1_id)

      assert [%Match{id: ^match_id, profile: %Profile{user_id: ^p2_id}}] =
               Matches.get_current_matches(p1.user_id)

      assert [%Match{id: ^match_id, profile: %Profile{user_id: ^p1_id}}] =
               Matches.get_current_matches(p2.user_id)

      Matches.subscribe_for_match(match_id)

      assert [] == Feeds.all_profile_likes_with_liker_profile(p1_id)
      assert [] == Feeds.all_profile_likes_with_liker_profile(p2_id)

      assert {:ok, _user_ids} = Matches.unmatch(user: p1.user_id, match: match_id)

      assert_receive {Matches, [:unmatched, ^match_id], [_, _] = user_ids}
      assert p1.user_id in user_ids
      assert p2.user_id in user_ids

      refute Repo.get(Profile, p1.user_id).hidden?
      refute Repo.get(Profile, p2.user_id).hidden?

      assert [] == Matches.get_current_matches(p1.user_id)
      assert [] == Matches.get_current_matches(p2.user_id)

      assert [] == Feeds.all_profile_likes_with_liker_profile(p1_id)
      assert [] == Feeds.all_profile_likes_with_liker_profile(p2_id)

      assert [
               %Oban.Job{args: %{"match_id" => ^match_id, "type" => "match"}},
               %Oban.Job{args: %{"by_user_id" => ^p1_id, "type" => "like", "user_id" => ^p2_id}}
             ] = all_enqueued(worker: T.PushNotifications.DispatchJob)
    end
  end
end
