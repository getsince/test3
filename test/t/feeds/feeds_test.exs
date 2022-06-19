defmodule T.FeedsTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: T.Repo

  alias T.Feeds
  alias T.Feeds.{FeedProfile, FeedFilter, SeenProfile}

  doctest Feeds, import: true

  describe "fetch_feed/3" do
    setup do
      me = onboarded_user(location: moscow_location())
      {:ok, me: me}
    end

    test "with no data in db", %{me: me} do
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
    end

    test "with no active users", %{me: me} do
      insert_list(3, :profile, gender: "F")

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
    end

    test "with no users of preferred gender", %{me: me} do
      _others = insert_list(3, :profile, gender: "M")

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
    end

    test "with users of preferred gender but not interested", %{me: me} do
      others = insert_list(3, :profile, gender: "F")

      for profile <- others do
        insert(:gender_preference, user_id: profile.user_id, gender: "F")
      end

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
    end
  end

  describe "mark_profile_seen/2" do
    setup do
      me = onboarded_user(location: moscow_location())
      {:ok, me: me}
    end

    test "with unseen profile", %{me: me} do
      mate = onboarded_user()

      Feeds.mark_profile_seen(mate.id, by: me.id)

      mate_id = mate.id
      me_id = me.id

      assert [%{user_id: ^mate_id, by_user_id: ^me_id}] = SeenProfile |> Repo.all()

      assert FeedProfile
             |> where(user_id: ^mate_id)
             |> select([p], {p.times_shown, p.like_ratio})
             |> Repo.one!() ==
               {1, 0.0}
    end

    test "with seen profile", %{me: me} do
      mate = onboarded_user()

      Repo.insert(%SeenProfile{user_id: mate.id, by_user_id: me.id})

      Feeds.mark_profile_seen(mate.id, by: me.id)

      mate_id = mate.id

      assert FeedProfile
             |> where(user_id: ^mate_id)
             |> select([p], {p.times_shown, p.like_ratio})
             |> Repo.one!() ==
               {0, 0.0}
    end
  end

  describe "fetch_onboarding_feed/2" do
    test "with no data in db" do
      assert [] == Feeds.fetch_onboarding_feed(nil, 0)
    end

    test "with no ip" do
      mate = onboarded_user()

      assert [%FeedProfile{user_id: user_id}] = Feeds.fetch_onboarding_feed(nil, 0)
      assert user_id == mate.id
    end
  end
end
