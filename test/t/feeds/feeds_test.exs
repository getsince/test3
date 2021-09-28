defmodule T.FeedsTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: T.Repo

  alias T.{Feeds, Accounts}
  alias T.PushNotifications.DispatchJob
  alias Feeds.{FeedProfile}

  @reference ~U[2021-07-21 11:55:18.941048Z]

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
                 _gender_preference = ["F"],
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
                 _gender_preference = ["F"],
                 _count = 10,
                 _cursor = nil
               )
    end

    test "with no users of preferred gender", %{me: me} do
      others = insert_list(3, :profile, gender: "M")
      activate_sessions(others, @reference)

      assert {[], nil} ==
               Feeds.fetch_feed(
                 me.id,
                 me.profile.location,
                 _gender = "M",
                 _gender_preference = ["F"],
                 _count = 10,
                 _cursor = nil
               )
    end

    test "with users of preferred gender but not interested", %{me: me} do
      others = insert_list(3, :profile, gender: "F")

      for profile <- others do
        insert(:gender_preference, user_id: profile.user_id, gender: "F")
      end

      activate_sessions(others, @reference)

      assert {[], nil} ==
               Feeds.fetch_feed(
                 me.id,
                 me.profile.location,
                 _gender = "M",
                 _gender_preference = ["F"],
                 _count = 10,
                 _cursor = nil
               )
    end
end
