defmodule T.Feeds.SeenTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: T.Repo

  alias T.Feeds
  alias T.Feeds.{FeedFilter, SeenProfile}

  describe "feed" do
    setup do
      me = onboarded_user(location: moscow_location())
      {:ok, me: me}
    end

    test "seen profile is not returned in feed", %{me: me} do
      assert {[], nil} ==
               Feeds.fetch_feed(
                 me.id,
                 me.profile.location,
                 _gender = "M",
                 _feed_filter = %FeedFilter{
                   genders: ["F"],
                   min_age: nil,
                   max_age: nil,
                   distance: nil
                 },
                 _count = 10,
                 _cursor = nil
               )

      now = DateTime.utc_now()

      others =
        insert_list(10, :profile,
          gender: "F",
          hidden?: false,
          last_active: now
        )

      for profile <- others do
        insert(:gender_preference, user_id: profile.user_id, gender: "M")
      end

      # I get the feed, nobody is "seen"
      assert {not_seen, _some} =
               Feeds.fetch_feed(
                 me.id,
                 me.profile.location,
                 _gender = "M",
                 _feed_filter = %FeedFilter{
                   genders: ["F"],
                   min_age: nil,
                   max_age: nil,
                   distance: nil
                 },
                 _count = 10,
                 _cursor = nil
               )

      assert length(not_seen) == 10

      # then I "see" some profiles (test broadcast)
      to_be_seen = Enum.take(not_seen, 3)

      Enum.each(to_be_seen, fn p ->
        # TODO verify broadcast
        assert {:ok, %SeenProfile{}} = Feeds.mark_profile_seen(p.user_id, by: me.id)
      end)

      # then I get feed again, and those profiles I've seen are marked as "seen"
      assert {loaded, _some} =
               Feeds.fetch_feed(
                 me.id,
                 me.profile.location,
                 _gender = "M",
                 _feed_filter = %FeedFilter{
                   genders: ["F"],
                   min_age: nil,
                   max_age: nil,
                   distance: nil
                 },
                 _count = 10,
                 _cursor = nil
               )

      assert length(loaded) == 7
      # TODO
      # also the profiles I've seen are put in the end of the list?
    end

    test "double mark_profile_seen doesn't raise but returns invalid changeset" do
      me = insert(:user)
      not_me = insert(:user)

      assert {:ok, %SeenProfile{}} = Feeds.mark_profile_seen(not_me.id, by: me.id)

      assert {:error, %Ecto.Changeset{valid?: false} = changeset} =
               Feeds.mark_profile_seen(not_me.id, by: me.id)

      assert errors_on(changeset) == %{seen: ["has already been taken"]}
    end

    test "seen_profiles are pruned" do
      me = insert(:user)
      not_me = insert(:user)
      long_ago = DateTime.add(DateTime.utc_now(), -32 * 24 * 60 * 60)

      insert(:seen_profile, by_user: me, user: not_me, inserted_at: long_ago)

      seen_profiles =
        SeenProfile
        |> T.Repo.all()

      assert length(seen_profiles) == 1

      Feeds.local_prune_seen_profiles(5)

      seen_profiles_after =
        SeenProfile
        |> T.Repo.all()

      assert length(seen_profiles_after) == 0
    end
  end
end
