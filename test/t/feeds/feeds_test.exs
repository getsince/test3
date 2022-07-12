defmodule T.FeedsTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: T.Repo

  alias T.Feeds
  alias T.Feeds.{FeedProfile, SeenProfile}

  doctest Feeds, import: true

  describe "fetch_feed/3" do
    setup do
      me = onboarded_user(location: moscow_location())
      {:ok, me: me}
    end

    test "with no data in db", %{me: me} do
      assert [] == Feeds.fetch_feed(me.id, me.profile.location, true)
    end

    test "with feed_daily_limit reached", %{me: me} do
      for _ <- 1..Feeds.feed_daily_limit(), do: onboarded_user()

      # first we fetch feed on channel join
      feed = Feeds.fetch_feed(me.id, me.profile.location, true)
      assert length(feed) == Feeds.feed_fetch_count()

      # then we fetch feed on "more" command
      for _ <- 3..Integer.floor_div(Feeds.feed_daily_limit(), Feeds.feed_fetch_count()) do
        feed = Feeds.fetch_feed(me.id, me.profile.location, false)
        assert length(feed) == Feeds.feed_fetch_count()
      end

      # to test the correct feed adjusted_count
      p = onboarded_user()
      Repo.insert(%SeenProfile{user_id: p.id, by_user_id: me.id})
      feed = Feeds.fetch_feed(me.id, me.profile.location, false)
      assert length(feed) == Feeds.feed_fetch_count() - 1

      assert {%DateTime{}, [%{}] = _story} = Feeds.fetch_feed(me.id, me.profile.location, true)
    end

    test "first_fetch", %{me: me} do
      for _ <- 1..(Feeds.feed_fetch_count() * 2), do: onboarded_user()

      # users joins and receives feed
      feed = Feeds.fetch_feed(me.id, me.profile.location, true)
      assert length(feed) == Feeds.feed_fetch_count()

      # but never watches it (no seen commands)
      # asks for more users, gets the second batch
      feed = Feeds.fetch_feed(me.id, me.profile.location, false)
      assert length(feed) == Feeds.feed_fetch_count()

      # asks for more, gets nobody since everybody was "feeded" to him
      feed = Feeds.fetch_feed(me.id, me.profile.location, false)
      assert feed == []

      # but on reentering the app gets feed again since none of it was really watched
      feed = Feeds.fetch_feed(me.id, me.profile.location, true)
      assert length(feed) == Feeds.feed_fetch_count()
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
