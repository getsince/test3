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
      profiles: [p1, p2]
    } do
      insert(:like, user: p1.user, by_user: p2.user)

      assert {:ok, %{match: %Match{id: match_id, alive?: true} = match}} =
               Feeds.like_profile(p1.user_id, p2.user_id)

      assert times_liked(p2.user_id) == 1
      # assert_seen(by_user_id: p1.user_id, user_id: p2.user_id)
      assert_liked(by_user_id: p1.user_id, user_id: p2.user_id)

      # one match never hide nobody
      refute_hidden([p1.user_id, p2.user_id])

      assert p1.user_id in [match.user_id_1, match.user_id_2]
      assert p2.user_id in [match.user_id_1, match.user_id_2]

      assert_receive {Matches, [:matched, ^match_id], [_, _] = user_ids}
      assert_receive {Matches, [:matched, ^match_id], ^user_ids}

      assert p1.user_id in user_ids
      assert p2.user_id in user_ids

      assert [%{args: %{"match_id" => ^match_id, "type" => "match"}}] =
               all_enqueued(worker: T.PushNotifications.DispatchJob)
    end

    test "match once, match twice not hidden! match thrice -> hidden!", %{profiles: [p1, p2]} do
      [p3, p4] = insert_list(2, :profile)

      Matches.subscribe_for_user(p3.user_id)
      Matches.subscribe_for_user(p4.user_id)

      ids = Enum.map([p1, p2] ++ [p3, p4], & &1.user_id)

      assert {:ok, %{match: nil}} = Feeds.like_profile(p1.user_id, p2.user_id)
      assert {:ok, %{match: nil}} = Feeds.like_profile(p1.user_id, p3.user_id)

      # match 1 (p1+p2)

      assert {:ok, %{match: %Match{id: m12, alive?: true}}} =
               Feeds.like_profile(p2.user_id, p1.user_id)

      refute_hidden([p1.user_id, p2.user_id])
      assert_receive {Matches, [:matched, ^m12], [_, _] = user_ids}
      assert_receive {Matches, [:matched, ^m12], ^user_ids}
      assert p1.user_id in user_ids
      assert p2.user_id in user_ids

      assert Matches.profiles_with_match_count(ids) == %{
               p1.user_id => 1,
               p2.user_id => 1,
               p3.user_id => 0,
               p4.user_id => 0
             }

      assert {:ok, %{match: nil}} = Feeds.like_profile(p1.user_id, p4.user_id)

      # match 2 (p1+p3)

      assert {:ok, %{match: %Match{id: m13, alive?: true}}} =
               Feeds.like_profile(p3.user_id, p1.user_id)

      refute_hidden([p1.user_id, p3.user_id])
      assert_receive {Matches, [:matched, ^m13], [_, _] = user_ids}
      assert_receive {Matches, [:matched, ^m13], ^user_ids}
      assert p1.user_id in user_ids
      assert p3.user_id in user_ids

      assert Matches.profiles_with_match_count(ids) == %{
               p1.user_id => 2,
               p2.user_id => 1,
               p3.user_id => 1,
               p4.user_id => 0
             }

      assert {:ok, %{match: nil}} = Feeds.like_profile(p2.user_id, p3.user_id)

      # match 3 (p2+p3)

      assert {:ok, %{match: %Match{id: m23, alive?: true}}} =
               Feeds.like_profile(p3.user_id, p2.user_id)

      refute_hidden([p2.user_id, p3.user_id])
      assert_receive {Matches, [:matched, ^m23], [_, _] = user_ids}
      assert_receive {Matches, [:matched, ^m23], ^user_ids}
      assert p2.user_id in user_ids
      assert p3.user_id in user_ids

      assert Matches.profiles_with_match_count(ids) == %{
               p1.user_id => 2,
               p2.user_id => 2,
               p3.user_id => 2,
               p4.user_id => 0
             }

      # match 4 (p1+p4)

      assert {:ok, %{match: %Match{id: m14, alive?: true}}} =
               Feeds.like_profile(p4.user_id, p1.user_id)

      assert_hidden([p1.user_id])
      assert_receive {Matches, [:matched, ^m14], [_, _] = user_ids}
      assert_receive {Matches, [:matched, ^m14], ^user_ids}
      assert p1.user_id in user_ids
      assert p4.user_id in user_ids

      assert Matches.profiles_with_match_count(ids) == %{
               p1.user_id => 3,
               p2.user_id => 2,
               p3.user_id => 2,
               p4.user_id => 1
             }

      # TODO p1 can't like no more?

      assert [
               %{args: %{"match_id" => ^m14, "type" => "match"}},
               %{args: %{"match_id" => ^m23, "type" => "match"}},
               %{args: %{"match_id" => ^m13, "type" => "match"}},
               %{args: %{"match_id" => ^m12, "type" => "match"}}
             ] = all_enqueued(worker: T.PushNotifications.DispatchJob)

      refute_receive _anything_else
    end

    test "doesn't create match if not yet liked", %{profiles: [p1, p2]} do
      assert {:ok, %{match: nil}} = Feeds.like_profile(p1.user_id, p2.user_id)

      assert times_liked(p2.user_id) == 1
      # assert_seen(by_user_id: p1.user_id, user_id: p2.user_id)
      assert_liked(by_user_id: p1.user_id, user_id: p2.user_id)
      refute_hidden([p1.user_id, p2.user_id])

      refute_receive _anything
      assert [] = all_enqueued(worker: T.PushNotifications.DispatchJob)
    end

    test "double like doesn't raise", %{profiles: [p1, p2]} do
      assert {:ok, %{match: nil}} = Feeds.like_profile(p1.user_id, p2.user_id)
      assert {:error, :like, changeset, _changes} = Feeds.like_profile(p1.user_id, p2.user_id)
      assert errors_on(changeset) == %{like: ["has already been taken"]}
    end
  end

  describe "get_or_create_feed/2" do
    setup do
      {:ok, me: insert(:profile, gender: "M", city: "Tashkent")}
    end

    test "when there are no users", %{me: me} do
      assert [] == Feeds.get_or_create_feed(me)
    end

    test "when there is a precomputed feed", %{me: me} do
      today = Date.utc_today()
      profiles = insert_list(5, :profile, gender: "F")

      insert(:feed,
        user_id: me.user_id,
        profiles: Map.new(profiles, &{&1.user_id, "very compatible jk it's actually an ad"}),
        date: today
      )

      feed = Feeds.get_or_create_feed(me, today)

      assert_reasons(feed, [
        "very compatible jk it's actually an ad",
        "very compatible jk it's actually an ad",
        "very compatible jk it's actually an ad",
        "very compatible jk it's actually an ad",
        "very compatible jk it's actually an ad"
      ])

      for profile <- profiles do
        assert_feed_has_profile(feed, profile)
      end
    end

    test "where there are some users but no personality overlap or likes", %{me: me} do
      insert_list(5, :profile, gender: "F", city: me.city)
      assert feed = Feeds.get_or_create_feed(me)
      # TODO 5
      assert length(feed) == 4
      assert_unique_profiles(feed)

      assert_reasons(feed, [
        "most liked",
        "most liked",
        "non rated with (possible) overlap",
        "non rated with (possible) overlap"
      ])

      # verify stored
      assert feed2 = Feeds.get_or_create_feed(me)

      assert_reasons(feed2, [
        "most liked",
        "most liked",
        "non rated with (possible) overlap",
        "non rated with (possible) overlap"
      ])

      assert_lists_equal(feed, feed2, fn p1, p2 -> p1.user_id == p2.user_id end)
    end

    test "when there are most rated users", %{me: me} do
      profiles = insert_list(20, :profile, gender: "F", city: me.city)
      [top1 | [top2 | _rest]] = most_liked(profiles, 30..25)

      feed = Feeds.get_or_create_feed(me)
      assert_unique_profiles(feed)
      assert_feed_has_profile(feed, top1)
      assert_feed_has_profile(feed, top2)

      assert_reasons(feed, [
        "most liked",
        "most liked",
        "non rated with (possible) overlap",
        "non rated with (possible) overlap"
      ])

      # still no personality overlap
      assert length(feed) == 4

      # the rest are non rated
      non_rated = Enum.filter(feed, &(&1.times_liked == 0))
      assert length(non_rated) == 2
    end

    test "when there are personality overlap scores and no most rated", %{me: me} do
      profiles = insert_list(20, :profile, gender: "F", city: me.city)

      [top1 | _rest] = personality_overlap(profiles, me, 30..25)
      feed = Feeds.get_or_create_feed(me)
      assert_unique_profiles(feed)
      assert_feed_has_profile(feed, top1)

      assert_reasons(feed, [
        "most overlap",
        "non rated with (possible) overlap",
        "most liked",
        "most liked",
        "non rated with (possible) overlap"
      ])

      assert length(feed) == 5
      # and nobody has any likes
      non_rated = Enum.filter(feed, &(&1.times_liked == 0))
      assert length(non_rated) == 5
    end

    @tag skip: true
    test "when there are personality overlap scores and some most rated"

    @tag skip: true
    test "when there are likers"

    test "when there are users of ALL kinds", %{me: me} do
      profiles = insert_list(20, :profile, gender: "F", city: me.city)

      [place1 | [place2 | _rest]] = most_liked(profiles, 30..15)
      [place3 | [place4 | _rest]] = personality_overlap(profiles, me, 30..10)
      insert(:like, by_user_id: place4.user_id, user_id: me.user_id)

      feed = Feeds.get_or_create_feed(me)
      assert_unique_profiles(feed)
      assert length(feed) == 5

      # assert_reasons(feed, [
      #   "has liked with (possible) overlap",
      #   "most overlap",
      #   "most liked",
      #   "most liked",
      #   "non rated with (possible) overlap"
      # ])

      assert_feed_has_profile(feed, place1)
      assert_feed_has_profile(feed, place2)
      assert_feed_has_profile(feed, place3)
      assert_feed_has_profile(feed, place4)

      assert Enum.any?(feed, &(&1.times_liked == 0))
    end

    @tag skip: true
    test "when there are no non_rated users"
  end
end
