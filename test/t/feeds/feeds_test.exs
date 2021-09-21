defmodule T.FeedsTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: T.Repo

  alias T.{Feeds, Accounts}
  alias T.PushNotifications.DispatchJob
  alias Feeds.{ActiveSession, FeedProfile}

  @reference ~U[2021-07-21 11:55:18.941048Z]

  describe "activate_session/2" do
    test "doesn't raise on conflict, latest session takes precedence" do
      user = insert(:user)
      reference = ~U[2021-07-21 10:55:18.941048Z]

      assert %ActiveSession{expires_at: ~U[2021-07-21 11:55:18Z]} =
               Feeds.activate_session(user.id, _hour = 60, reference)

      # TODO what happens with invites? right now they are probably all deleted
      assert %ActiveSession{expires_at: ~U[2021-07-21 11:15:18Z]} =
               Feeds.activate_session(user.id, _20_mins = 20, reference)

      assert %ActiveSession{expires_at: ~U[2021-07-21 11:15:18Z]} =
               Feeds.get_current_session(user.id)
    end
  end

  describe "invite_active_user/2" do
    setup do
      [u1, u2] = users = insert_list(2, :user)

      :ok = Feeds.subscribe_for_invites(u1.id)
      :ok = Feeds.subscribe_for_invites(u2.id)

      {:ok, users: users}
    end

    test "when both users not active", %{users: [u1, u2]} do
      assert false == Feeds.invite_active_user(u1.id, u2.id)

      assert [] = all_enqueued(worder: DispatchJob)
      refute_receive _anything
    end

    test "when inviter is not active", %{users: [u1, u2]} do
      Feeds.activate_session(u2.id, 60)

      assert false == Feeds.invite_active_user(u1.id, u2.id)

      assert [] = all_enqueued(worder: DispatchJob)
      refute_receive _anything
    end

    test "when invitee is not active", %{users: [u1, u2]} do
      Feeds.activate_session(u1.id, 60)

      assert false == Feeds.invite_active_user(u1.id, u2.id)

      assert [] = all_enqueued(worder: DispatchJob)
      refute_receive _anything
    end

    test "when both users are active", %{users: [%{id: u1_id}, %{id: u2_id}]} do
      Feeds.activate_session(u1_id, 60)
      Feeds.activate_session(u2_id, 60)

      assert true == Feeds.invite_active_user(u1_id, u2_id)

      assert [%Oban.Job{args: %{"type" => "invite", "by_user_id" => ^u1_id, "user_id" => ^u2_id}}] =
               all_enqueued(worder: DispatchJob)

      assert_receive {Feeds, :invited, ^u1_id}
      refute_receive _anything_else
    end

    test "no duplicate notifications on duplicate invite", %{users: [u1, u2]} do
      Feeds.activate_session(u1.id, 60)
      Feeds.activate_session(u2.id, 60)

      assert true == Feeds.invite_active_user(u1.id, u2.id)
      assert false == Feeds.invite_active_user(u1.id, u2.id)

      assert [%Oban.Job{}] = all_enqueued(worder: DispatchJob)

      assert_receive {Feeds, :invited, _by_user_id}
      refute_receive _anything_else
    end

    @tag skip: true
    test "when inviter is reported by invitee"
  end

  describe "deactivate_session/1" do
    setup do
      [u1, u2] =
        users = [
          onboarded_user(location: moscow_location()),
          onboarded_user(location: apple_location())
        ]

      :ok = Feeds.subscribe_for_invites(u1.id)
      :ok = Feeds.subscribe_for_invites(u2.id)

      {:ok, users: users}
    end

    test "invites are cleared when session is deactivated for inviter", %{users: [u1, u2]} do
      Feeds.activate_session(u1.id, 60, @reference)
      Feeds.activate_session(u2.id, 60, @reference)

      assert true == Feeds.invite_active_user(u1.id, u2.id)

      assert [
               {%FeedProfile{} = feed_profile,
                %ActiveSession{expires_at: ~U[2021-07-21 12:55:18Z]}, _distance_km = 9510}
             ] = Feeds.list_received_invites(u2.id, u2.profile.location)

      assert feed_profile.user_id == u1.id

      assert true == Feeds.deactivate_session(u1.id)
      assert [] == Feeds.list_received_invites(u2.id, u2.profile.location)
    end

    test "invites are cleared when session is deactivated for invitee", %{users: [u1, u2]} do
      Feeds.activate_session(u1.id, 60, @reference)
      Feeds.activate_session(u2.id, 60, @reference)

      assert true == Feeds.invite_active_user(u1.id, u2.id)

      assert [
               {%FeedProfile{} = feed_profile,
                %ActiveSession{expires_at: ~U[2021-07-21 12:55:18Z]}, _distance_km = 9510}
             ] = Feeds.list_received_invites(u2.id, u2.profile.location)

      assert feed_profile.user_id == u1.id

      assert true == Feeds.deactivate_session(u2.id)
      assert [] == Feeds.list_received_invites(u2.id, u2.profile.location)
    end
  end

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

    test "with active users fewer than count", %{me: me} do
      others =
        Enum.map(1..3, fn _ ->
          onboarded_user(gender: "F", location: apple_location(), accept_genders: ["M", "N"])
        end)

      activate_sessions(others, @reference)

      assert {[
                {%FeedProfile{}, %ActiveSession{expires_at: ~U[2021-07-21 12:55:18Z]},
                 _distance = 9510},
                {%FeedProfile{}, %ActiveSession{expires_at: ~U[2021-07-21 12:55:18Z]}, 9510},
                {%FeedProfile{},
                 %ActiveSession{flake: cursor, expires_at: ~U[2021-07-21 12:55:18Z]}, 9510}
              ],
              cursor} =
               Feeds.fetch_feed(
                 me.id,
                 me.profile.location,
                 _gender = "M",
                 _gender_preference = ["F"],
                 _count = 10,
                 _cursor = nil
               )

      assert {[], ^cursor} =
               Feeds.fetch_feed(
                 me.id,
                 me.profile.location,
                 _gender = "M",
                 _gender_preference = ["F"],
                 _count = 10,
                 cursor
               )
    end

    test "with active users more than count", %{me: me} do
      others =
        Enum.map(1..3, fn _ ->
          onboarded_user(gender: "F", location: apple_location(), accept_genders: ["M", "N"])
        end)

      activate_sessions(others, @reference)

      assert {[
                {%FeedProfile{}, %ActiveSession{expires_at: ~U[2021-07-21 12:55:18Z]},
                 _distance = 9510},
                {%FeedProfile{},
                 %ActiveSession{flake: cursor1, expires_at: ~U[2021-07-21 12:55:18Z]}, 9510}
              ],
              cursor1} =
               Feeds.fetch_feed(
                 me.id,
                 me.profile.location,
                 _gender = "M",
                 _gender_preference = ["F"],
                 _count = 2,
                 _cursor = nil
               )

      assert {[
                {%FeedProfile{},
                 %ActiveSession{flake: cursor2, expires_at: ~U[2021-07-21 12:55:18Z]}, 9510}
              ],
              cursor2} =
               Feeds.fetch_feed(
                 me.id,
                 me.profile.location,
                 _gender = "M",
                 _gender_preference = ["F"],
                 _count = 10,
                 cursor1
               )

      assert cursor2 != cursor1

      assert {[], ^cursor2} =
               Feeds.fetch_feed(
                 me.id,
                 me.profile.location,
                 _gender = "M",
                 _gender_preference = ["F"],
                 _count = 10,
                 cursor2
               )
    end
  end

  describe "get_feed_item/1" do
    setup do
      me = onboarded_user(location: moscow_location())
      other = onboarded_user(location: apple_location())
      activate_session(other, @reference)
      {:ok, me: me, other: other}
    end

    test "returns non reported user", %{me: me, other: other} do
      assert {%FeedProfile{}, %ActiveSession{expires_at: ~U[2021-07-21 12:55:18Z]},
              _distance_km = 9510} = Feeds.get_feed_item(me.id, me.profile.location, other.id)
    end

    test "doesn't return reported user", %{me: me, other: other} do
      assert :ok = Accounts.report_user(me.id, other.id, "ugly")
      refute Feeds.get_feed_item(me.id, me.profile.location, other.id)
    end
  end
end
