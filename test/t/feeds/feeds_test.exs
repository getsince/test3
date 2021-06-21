defmodule T.FeedsTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: T.Repo
  alias T.{Feeds, Matches}
  alias T.Matches.Match

  describe "like_profile/2" do
    setup do
      [p1, p2] = insert_list(2, :profile)

      Matches.subscribe_for_user(p1.user_id)
      Matches.subscribe_for_user(p2.user_id)

      {:ok, profiles: [p1, p2]}
    end

    test "creates match if user is already liked and the liker is not hidden", %{
      profiles: profiles
    } do
      [%{user_id: uid1}, %{user_id: uid2}] = profiles
      assert {:ok, %{match: nil}} = Feeds.like_profile(uid2, uid1)

      assert {:ok, %{match: %Match{id: match_id, alive?: true} = match}} =
               Feeds.like_profile(uid1, uid2)

      assert times_liked(uid2) == 1
      assert_liked(by_user_id: uid1, user_id: uid2)

      user_ids = [uid1, uid2]
      refute_hidden(user_ids)

      assert_lists_equal(user_ids, [match.user_id_1, match.user_id_2])
      assert_receive {Matches, [:matched, ^match_id], ^user_ids}
      assert_receive {Matches, [:matched, ^match_id], ^user_ids}

      assert [
               %Oban.Job{args: %{"type" => "match", "match_id" => ^match_id}},
               %Oban.Job{
                 args: %{"type" => "like", "by_user_id" => ^uid2, "user_id" => ^uid1}
               }
             ] = all_enqueued(worker: T.PushNotifications.DispatchJob)
    end

    test "doesn't create match if not yet liked", %{profiles: profiles} do
      [%{user_id: liker_id}, %{user_id: liked_id}] = profiles

      assert times_liked(liked_id) == 0
      assert {:ok, %{match: nil}} = Feeds.like_profile(liker_id, liked_id)
      assert times_liked(liked_id) == 1

      assert_liked(by_user_id: liker_id, user_id: liked_id)
      refute_hidden([liker_id, liked_id])

      refute_receive _anything

      assert [
               %Oban.Job{
                 args: %{"type" => "like", "by_user_id" => ^liker_id, "user_id" => ^liked_id}
               }
             ] = all_enqueued(worker: T.PushNotifications.DispatchJob)
    end

    test "double like doesn't raise", %{profiles: [p1, p2]} do
      assert {:ok, %{match: nil}} = Feeds.like_profile(p1.user_id, p2.user_id)
      assert {:error, :like, changeset, _changes} = Feeds.like_profile(p1.user_id, p2.user_id)
      assert errors_on(changeset) == %{like: ["has already been taken"]}
    end
  end
end
