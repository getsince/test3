defmodule Since.FeedsTest do
  use Since.DataCase, async: true
  use Oban.Testing, repo: Since.Repo

  alias Since.Feeds
  alias Since.Feeds.{FeedProfile, FeedFilter, SeenProfile, CalculatedFeed, Meeting}

  doctest Feeds, import: true

  describe "fetch_feed/3" do
    setup do
      me = onboarded_user(location: moscow_location())
      # so that our onboarded_user is not treated as the first-time user when being served feed
      not_me = insert(:user)
      inserted_at = DateTime.utc_now() |> DateTime.add(-Feeds.feed_limit_period())
      insert(:seen_profile, by_user: me, user: not_me, inserted_at: inserted_at)
      {:ok, me: me}
    end

    test "with no data in db", %{me: me} do
      assert [] ==
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
                 _first_fetch = true
               )
    end

    test "with no active users", %{me: me} do
      insert_list(3, :profile, gender: "F")

      assert [] ==
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
                 _first_fetch = true
               )
    end

    test "with no users of preferred gender", %{me: me} do
      _others = insert_list(3, :profile, gender: "M")

      assert [] ==
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
                 _first_fetch = true
               )
    end

    test "with users of preferred gender but not interested", %{me: me} do
      others = insert_list(3, :profile, gender: "F")

      for profile <- others do
        insert(:gender_preference, user_id: profile.user_id, gender: "F")
      end

      assert [] ==
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
                 _first_fetch = true
               )
    end

    test "for newly onboarded user" do
      new_user = onboarded_user()

      for _ <- 1..Feeds.feed_fetch_count(), do: onboarded_user()

      for _ <- 1..Feeds.feed_fetch_count() do
        u =
          onboarded_user(
            story: [
              %{"background" => %{"s3_key" => "public1"}, "labels" => [], "size" => [400, 100]},
              %{"background" => %{"s3_key" => "public2"}, "labels" => [], "size" => [400, 100]},
              %{"background" => %{"s3_key" => "public2"}, "labels" => [], "size" => [400, 100]}
            ]
          )

        FeedProfile
        |> where(user_id: ^u.id)
        |> update(set: [times_liked: ^Feeds.quality_likes_count_treshold()])
        |> Repo.update_all([])
      end

      for _ <- 1..Feeds.feed_fetch_count(), do: onboarded_user()

      feed =
        Feeds.fetch_feed(
          new_user.id,
          new_user.profile.location,
          new_user.profile.gender,
          _feed_filter = %FeedFilter{
            genders: ["F", "M", "N"],
            min_age: nil,
            max_age: nil,
            distance: nil
          },
          true
        )

      assert length(feed) == Feeds.feed_fetch_count()

      for f <- feed do
        assert length(f.story) > 2
        assert f.times_liked >= Feeds.quality_likes_count_treshold()
      end
    end

    test "first_fetch", %{me: me} do
      for _ <- 1..(Feeds.feed_fetch_count() * 2), do: onboarded_user()

      # users joins and receives feed
      feed =
        Feeds.fetch_feed(
          me.id,
          me.profile.location,
          _gender = "M",
          _feed_filter = %FeedFilter{
            genders: ["F", "M", "N"],
            min_age: nil,
            max_age: nil,
            distance: nil
          },
          true
        )

      assert length(feed) == Feeds.feed_fetch_count()

      # but never watches it (no seen commands)
      # asks for more users, gets the second batch
      feed =
        Feeds.fetch_feed(
          me.id,
          me.profile.location,
          _gender = "M",
          _feed_filter = %FeedFilter{
            genders: ["F", "M", "N"],
            min_age: nil,
            max_age: nil,
            distance: nil
          },
          false
        )

      assert length(feed) == Feeds.feed_fetch_count()

      # asks for more, gets nobody since everybody was "feeded" to him
      feed =
        Feeds.fetch_feed(
          me.id,
          me.profile.location,
          _gender = "M",
          _feed_filter = %FeedFilter{
            genders: ["F", "M", "N"],
            min_age: nil,
            max_age: nil,
            distance: nil
          },
          false
        )

      assert feed == []

      # but on reentering the app gets feed again since none of it was really watched
      # all the previously feeded profiles are returned at once
      feed =
        Feeds.fetch_feed(
          me.id,
          me.profile.location,
          _gender = "M",
          _feed_filter = %FeedFilter{
            genders: ["F", "M", "N"],
            min_age: nil,
            max_age: nil,
            distance: nil
          },
          true
        )

      assert length(feed) == Feeds.feed_fetch_count()
    end

    test "with calculated_feed", %{me: me} do
      regular_ids = for _ <- 1..Feeds.feed_fetch_count(), do: onboarded_user().id

      calculated_ids =
        for i <- 1..Feeds.feed_fetch_count() do
          u = onboarded_user()

          Repo.insert(%CalculatedFeed{
            for_user_id: me.id,
            user_id: u.id,
            score: i / Feeds.feed_fetch_count()
          })

          u.id
        end

      # users joins and receive calculated feed
      feed =
        Feeds.fetch_feed(
          me.id,
          me.profile.location,
          _gender = "M",
          _feed_filter = %FeedFilter{
            genders: ["F", "M", "N"],
            min_age: nil,
            max_age: nil,
            distance: nil
          },
          true
        )

      for %FeedProfile{user_id: user_id} <- feed do
        assert user_id not in regular_ids
        assert user_id in calculated_ids
      end

      # users fetches more and receive regular feed, since runs out of calculated feed
      feed =
        Feeds.fetch_feed(
          me.id,
          me.profile.location,
          _gender = "M",
          _feed_filter = %FeedFilter{
            genders: ["F", "M", "N"],
            min_age: nil,
            max_age: nil,
            distance: nil
          },
          false
        )

      for %FeedProfile{user_id: user_id} <- feed do
        assert user_id in regular_ids
        assert user_id not in calculated_ids
      end
    end

    test "with partly relevant calculated_feed", %{me: me} do
      regular_ids = for _ <- 1..Feeds.feed_fetch_count(), do: onboarded_user().id

      calculated_ids =
        for i <- 1..Feeds.feed_fetch_count() do
          u = onboarded_user()

          Repo.insert(%CalculatedFeed{
            for_user_id: me.id,
            user_id: u.id,
            score: i / Feeds.feed_fetch_count()
          })

          u.id
        end

      irrelevant_users_count = 0

      # hidden user
      uid = calculated_ids |> Enum.at(0)
      FeedProfile |> where(user_id: ^uid) |> Repo.update_all(set: [hidden?: true])
      irrelevant_users_count = irrelevant_users_count + 1

      # user who invited us
      uid = calculated_ids |> Enum.at(1)
      Since.Chats.save_message(me.id, uid, %{"question" => "invitation"})
      irrelevant_users_count = irrelevant_users_count + 1

      # user who we reported
      uid = calculated_ids |> Enum.at(2)

      %Since.Accounts.UserReport{on_user_id: uid, from_user_id: me.id, reason: "nude"}
      |> Repo.insert()

      irrelevant_users_count = irrelevant_users_count + 1

      # users joins and receive feed: partially calculated and partially regular
      feed =
        Feeds.fetch_feed(
          me.id,
          me.profile.location,
          _gender = "M",
          _feed_filter = %FeedFilter{
            genders: ["F", "M", "N"],
            min_age: nil,
            max_age: nil,
            distance: nil
          },
          true
        )

      calculated_count =
        feed |> Enum.count(fn %FeedProfile{user_id: user_id} -> user_id in calculated_ids end)

      regular_count =
        feed |> Enum.count(fn %FeedProfile{user_id: user_id} -> user_id in regular_ids end)

      assert calculated_count == Feeds.feed_fetch_count() - irrelevant_users_count
      assert regular_count == irrelevant_users_count

      # users fetches more and receive regular feed, since runs out of calculated feed
      feed =
        Feeds.fetch_feed(
          me.id,
          me.profile.location,
          _gender = "M",
          _feed_filter = %FeedFilter{
            genders: ["F", "M", "N"],
            min_age: nil,
            max_age: nil,
            distance: nil
          },
          false
        )

      assert length(feed) == Feeds.feed_fetch_count() - irrelevant_users_count
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
      mate =
        onboarded_user(
          story: [
            %{
              "background" => %{"s3_key" => "public1"},
              "labels" => [%{"answer" => "Yandex"}],
              "size" => [400, 100]
            },
            %{
              "background" => %{"s3_key" => "public1"},
              "labels" => [%{"answer" => "communication"}],
              "size" => [400, 100]
            },
            %{"background" => %{"s3_key" => "public1"}, "labels" => [], "size" => [400, 100]}
          ]
        )

      assert [%{profile: %FeedProfile{user_id: user_id}, categories: ["communication", "tech"]}] =
               Feeds.fetch_onboarding_feed(nil, 0)

      assert user_id == mate.id
    end

    test "with no quality profiles" do
      for _ <- 1..10, do: onboarded_user()

      assert Feeds.fetch_onboarding_feed(nil, 0) == []
    end
  end

  describe "fetch_meetings/3" do
    setup do
      me = onboarded_user(location: moscow_location())
      {:ok, me: me}
    end

    test "with no data in db", %{me: me} do
      assert [] == Feeds.fetch_meetings(me.id, me.profile.location, nil)
    end

    test "without cursor", %{me: me} do
      for _ <- 1..3 do
        user = onboarded_user()
        insert(:meeting, user: user)
      end

      meetings = Feeds.fetch_meetings(me.id, me.profile.location, nil)
      assert length(meetings) == 3
    end

    test "with cursor", %{me: me} do
      for _ <- 1..15 do
        user = onboarded_user()
        insert(:meeting, user: user)
      end

      meetings = Feeds.fetch_meetings(me.id, me.profile.location, nil)
      assert length(meetings) == 10

      meetings = Feeds.fetch_meetings(me.id, me.profile.location, nil)
      assert length(meetings) == 10

      cursor = List.last(meetings).id

      meetings = Feeds.fetch_meetings(me.id, me.profile.location, cursor)
      assert length(meetings) == 5
    end
  end

  describe "save_meeting/2" do
    setup do
      me = onboarded_user(location: moscow_location())
      {:ok, me: me}
    end

    test "with invalid meeting_data", %{me: me} do
      {:error, %Ecto.Changeset{valid?: false} = changeset} =
        Feeds.save_meeting(me.id, %{"value" => "bread"})

      assert errors_on(changeset) == %{meeting: ["unrecognized meeting type"]}
    end

    test "is available in feed", %{me: me} do
      {:ok, %Meeting{id: id}} =
        Feeds.save_meeting(me.id, %{"text" => "bread", "background" => %{"color" => "#A2ABEC"}})

      [meeting] = Feeds.fetch_meetings(me.id, me.profile.location, nil)
      assert meeting.id == id
    end
  end

  describe "delete_meeting/2" do
    setup do
      me = onboarded_user(location: moscow_location())
      {:ok, me: me}
    end

    test "with foreign meeting", %{me: me} do
      user = onboarded_user()
      m = insert(:meeting, user: user)

      assert :error == Feeds.delete_meeting(me.id, m.id)
    end

    test "deletes meeting", %{me: me} do
      m = insert(:meeting, user: me)

      [meeting] = Feeds.fetch_meetings(me.id, me.profile.location, nil)
      assert meeting.id == m.id

      assert :ok == Feeds.delete_meeting(me.id, m.id)

      assert [] == Feeds.fetch_meetings(me.id, me.profile.location, nil)
    end
  end
end
