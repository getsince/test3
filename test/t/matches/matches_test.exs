defmodule T.MatchesTest do
  use T.DataCase
  use Oban.Testing, repo: T.Repo

  import Assertions

  alias T.{Matches, Feeds, Feeds.FeedProfile, Calls.Call, PushNotifications.DispatchJob}
  alias Matches.{Match, Like}

  describe "unmatch" do
    test "match no longer, likes no longer, unmatched broadcasted" do
      [%{user_id: p1_id}, %{user_id: p2_id}] = insert_list(2, :profile, hidden?: false)

      Matches.subscribe_for_user(p1_id)
      Matches.subscribe_for_user(p2_id)

      spawn(fn ->
        Matches.subscribe_for_user(p1_id)
        Matches.subscribe_for_user(p2_id)

        assert {:ok, %{match: nil}} = Matches.like_user(p1_id, p2_id)

        # TODO why do we get matched message?
        # refute_receive _anything, 1
      end)

      assert_receive {Matches, :liked, like}
      assert like == %{by_user_id: p1_id}

      assert [%Like{by_user_id: ^p1_id, user_id: ^p2_id}] = list_likes_for(p2_id)

      assert {:ok, %{match: %Match{id: match_id}}} = Matches.like_user(p2_id, p1_id)

      # for p1
      assert_receive {Matches, :matched, %{id: ^match_id, mate: ^p2_id, audio_only: false}}

      assert [%Match{id: ^match_id, profile: %FeedProfile{user_id: ^p2_id}}] =
               Matches.list_matches(p1_id)

      assert [%Match{id: ^match_id, profile: %FeedProfile{user_id: ^p1_id}}] =
               Matches.list_matches(p2_id)

      parent = self()

      spawn(fn ->
        Ecto.Adapters.SQL.Sandbox.allow(T.Repo, parent, self())
        assert true == Matches.unmatch_match(p1_id, match_id)
      end)

      # for p1
      assert_receive {Matches, :unmatched, ^match_id}
      # for p2
      assert_receive {Matches, :unmatched, ^match_id}

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

  describe "like/2" do
    test "bump like count, like ratio" do
      [%{user_id: liked}, %{user_id: liker1}, %{user_id: liker2}, %{user_id: liker3}] =
        insert_list(4, :profile, hidden?: false)

      Matches.like_user(liker1, liked)

      assert FeedProfile
             |> where(user_id: ^liked)
             |> select([p], {p.times_liked, p.like_ratio})
             |> Repo.one!() == {1, 1.0}

      Feeds.mark_profile_seen(liked, by: liker1)

      Feeds.mark_profile_seen(liked, by: liker2)

      assert FeedProfile
             |> where(user_id: ^liked)
             |> select([p], {p.times_liked, p.like_ratio})
             |> Repo.one!() == {1, 0.5}

      Matches.like_user(liker3, liked)

      assert FeedProfile
             |> where(user_id: ^liked)
             |> select([p], {p.times_liked, p.like_ratio})
             |> Repo.one!() == {2, 0.6666666666666666}

      Feeds.mark_profile_seen(liked, by: liker2)

      assert FeedProfile
             |> where(user_id: ^liked)
             |> select([p], {p.times_liked, p.like_ratio})
             |> Repo.one!() == {2, 0.6666666666666666}
    end
  end

  describe "maybe_match_after_end_call/1" do
    defp successful_call(caller_id, called_id) do
      %Call{
        caller_id: caller_id,
        called_id: called_id,
        accepted_at: ~U[2021-12-29 11:08:18Z],
        ended_at: ~U[2021-12-29 11:12:22Z]
      }
    end

    test "creates a match when users haven't been matched yet and call was successful" do
      u1 = onboarded_user()
      u2 = onboarded_user()
      call = successful_call(u1.id, u2.id)

      assert %Match{} = match = Matches.maybe_match_after_end_call(call)

      assert match.user_id_1 == u1.id
      assert match.user_id_2 == u2.id
    end

    test "no-op when users are already matched" do
      u1 = onboarded_user()
      u2 = onboarded_user()

      {:ok, %{match: nil}} = Matches.like_user(u1.id, u2.id)
      {:ok, %{match: %Match{}}} = Matches.like_user(u2.id, u1.id)

      call = successful_call(u1.id, u2.id)
      refute Matches.maybe_match_after_end_call(call)
    end

    test "no-op on calls <1 minute in duration" do
      short_call = %Call{
        accepted_at: ~U[2021-12-29 11:08:18Z],
        ended_at: ~U[2021-12-29 11:09:17Z]
      }

      refute Matches.maybe_match_after_end_call(short_call)
    end

    test "no-op on unanswered calls" do
      unanswered_call = %Call{
        accepted_at: nil,
        ended_at: ~U[2021-12-29 11:09:17Z]
      }

      refute Matches.maybe_match_after_end_call(unanswered_call)
    end
  end

  describe "match interactions overwrite" do
    setup do
      u1 = onboarded_user()
      u2 = onboarded_user()

      {:ok, %{match: nil}} = Matches.like_user(u1.id, u2.id)
      {:ok, %{match: %Match{} = match}} = Matches.like_user(u2.id, u1.id)

      {:ok, users: [u1, u2], match: match}
    end

    test "timeslot offer deletes contacts", %{users: [u1, u2], match: %{id: match_id}} do
      # this contact will be deleted
      {:ok, %Matches.MatchContact{match_id: ^match_id}} =
        Matches.save_contacts_offer_for_match(u1.id, match_id, %{"telegram" => "@ruslandoga"})

      now = ~U[2021-12-30 07:53:12.115371Z]
      slots = ["2021-12-30T10:00:00Z", "2021-12-30T10:30:00Z"]
      {:ok, %Matches.Timeslot{}} = Matches.save_slots_offer_for_match(u2.id, match_id, slots, now)

      refute Matches.MatchContact |> where(match_id: ^match_id) |> Repo.exists?()
    end

    test "contact offer deletes timeslots", %{users: [u1, u2], match: %{id: match_id}} do
      now = ~U[2021-12-30 07:53:12.115371Z]
      slots = ["2021-12-30T10:00:00Z", "2021-12-30T10:30:00Z"]

      # this timeslots will be deleted
      {:ok, %Matches.Timeslot{match_id: ^match_id}} =
        Matches.save_slots_offer_for_match(u2.id, match_id, slots, now)

      {:ok, %Matches.MatchContact{}} =
        Matches.save_contacts_offer_for_match(u1.id, match_id, %{"telegram" => "@ruslandoga"})

      refute Matches.Timeslot |> where(match_id: ^match_id) |> Repo.exists?()
    end
  end

  defp list_likes_for(user_id) do
    Like
    |> where(user_id: ^user_id)
    |> Repo.all()
  end
end
