defmodule T.MatchesTest do
  use T.DataCase
  use Oban.Testing, repo: T.Repo

  alias T.{Matches, Feeds.FeedProfile, Accounts.Profile, PushNotifications.DispatchJob}
  alias Matches.{Match, Like}

  import Assertions

  describe "unmatch" do
    test "match no longer, likes no longer, unmatched broadcasted (ios v1)" do
      [%{user_id: p1_id}, %{user_id: p2_id}] = insert_list(2, :profile, hidden?: false)

      Matches.subscribe_for_user(p1_id)
      Matches.subscribe_for_user(p2_id)

      assert {:ok, %{match: nil}} = Matches.like_user(p1_id, p2_id, _notify_on_like? = false)
      assert [%Like{by_user_id: ^p1_id, user_id: ^p2_id}] = list_likes_for(p2_id)

      assert {:ok, %{match: %Match{id: match_id}}} =
               Matches.like_user(p2_id, p1_id, _notify_on_like? = false)

      # for p1
      assert_receive {Matches, :matched, %{id: ^match_id, mate: ^p2_id}}

      assert [%Match{id: ^match_id, profile: %FeedProfile{user_id: ^p2_id}}] =
               Matches.list_matches(p1_id)

      assert [%Match{id: ^match_id, profile: %FeedProfile{user_id: ^p1_id}}] =
               Matches.list_matches(p2_id)

      spawn(fn ->
        assert true == Matches.unmatch_match(p1_id, match_id)
      end)

      # for p1
      assert_receive {Matches, :unmatched, ^match_id}
      # for p2
      assert_receive {Matches, :unmatched, ^match_id}
      refute_receive _anything_else

      refute Repo.get(Profile, p1_id).hidden?
      refute Repo.get(Profile, p2_id).hidden?

      assert [] == Matches.list_matches(p1_id)
      assert [] == Matches.list_matches(p2_id)

      assert [] == list_likes_for(p1_id)
      assert [] == list_likes_for(p2_id)

      assert [%Oban.Job{args: %{"match_id" => ^match_id, "type" => "match"}}] =
               all_enqueued(worker: DispatchJob)
    end

    test "match no longer, likes no longer, unmatched broadcasted (ios v2)" do
      [%{user_id: p1_id}, %{user_id: p2_id}] = insert_list(2, :profile, hidden?: false)

      Matches.subscribe_for_user(p1_id)
      Matches.subscribe_for_user(p2_id)

      spawn(fn ->
        Matches.subscribe_for_user(p1_id)
        Matches.subscribe_for_user(p2_id)

        assert {:ok, %{match: nil}} = Matches.like_user(p1_id, p2_id, _notify_on_like? = true)

        # TODO why do we get matched message?
        # refute_receive _anything, 1
      end)

      assert_receive {Matches, :liked, like}
      assert like == %{by_user_id: p1_id}

      assert [%Like{by_user_id: ^p1_id, user_id: ^p2_id}] = list_likes_for(p2_id)

      assert {:ok, %{match: %Match{id: match_id}}} =
               Matches.like_user(p2_id, p1_id, _notify_on_like? = true)

      # for p1
      assert_receive {Matches, :matched, %{id: ^match_id, mate: ^p2_id}}

      assert [%Match{id: ^match_id, profile: %FeedProfile{user_id: ^p2_id}}] =
               Matches.list_matches(p1_id)

      assert [%Match{id: ^match_id, profile: %FeedProfile{user_id: ^p1_id}}] =
               Matches.list_matches(p2_id)

      spawn(fn ->
        assert true == Matches.unmatch_match(p1_id, match_id)
      end)

      # for p1
      assert_receive {Matches, :unmatched, ^match_id}
      # for p2
      assert_receive {Matches, :unmatched, ^match_id}
      refute_receive _anything_else

      assert [] == Matches.list_matches(p1_id)
      assert [] == Matches.list_matches(p2_id)

      assert [] == list_likes_for(p1_id)
      assert [] == list_likes_for(p2_id)

      expected = [
        %{"by_user_id" => p1_id, "type" => "invite", "user_id" => p2_id},
        %{"match_id" => match_id, "type" => "match"}
      ]

      actual = Enum.map(all_enqueued(worker: DispatchJob), fn job -> job.args end)

      assert_lists_equal(expected, actual)
    end
  end

  defp list_likes_for(user_id) do
    Like
    |> where(user_id: ^user_id)
    |> Repo.all()
  end
end
