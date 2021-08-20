defmodule T.FeedsTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: T.Repo

  alias T.{Feeds, Accounts}
  alias T.PushNotifications.DispatchJob
  alias Feeds.{ActiveSession, FeedProfile}

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

  describe "expired sessions" do
    @reference ~U[2021-07-21 11:55:18.941048Z]

    setup do
      [u1, u2, u3] = users = insert_list(3, :user)

      Feeds.activate_session(u1.id, 60, _reference = ~U[2021-07-21 10:50:18Z])
      Feeds.activate_session(u2.id, 60, _reference = ~U[2021-07-21 10:53:18Z])
      Feeds.activate_session(u3.id, 60, _reference = ~U[2021-07-21 10:56:18Z])

      {:ok, users: users}
    end

    test "expired_sessions/0 returns expired sessions" do
      assert [
               %ActiveSession{expires_at: ~U[2021-07-21 11:50:18Z]},
               %ActiveSession{expires_at: ~U[2021-07-21 11:53:18Z]}
             ] = Feeds.expired_sessions(@reference)
    end

    test "delete_expired_sessions/0 deletes expired sessions", %{users: [u1, u2, _u3]} do
      assert {2, [u1.id, u2.id]} == Feeds.delete_expired_sessions(@reference)
      assert [] == Feeds.expired_sessions(@reference)
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
      [p1, p2] = profiles = insert_list(2, :profile)

      :ok = Feeds.subscribe_for_invites(p1.user_id)
      :ok = Feeds.subscribe_for_invites(p2.user_id)

      {:ok, profiles: profiles}
    end

    test "invites are cleared when session is deactivated for inviter", %{profiles: [p1, p2]} do
      Feeds.activate_session(p1.user_id, 60, @reference)
      Feeds.activate_session(p2.user_id, 60, @reference)

      assert true == Feeds.invite_active_user(p1.user_id, p2.user_id)

      assert [
               {%FeedProfile{} = feed_profile,
                %ActiveSession{expires_at: ~U[2021-07-21 12:55:18Z]}}
             ] = Feeds.list_received_invites(p2.user_id)

      assert feed_profile.user_id == p1.user_id

      assert true == Feeds.deactivate_session(p1.user_id)
      assert [] == Feeds.list_received_invites(p2.user_id)
    end

    test "invites are cleared when session is deactivated for invitee", %{profiles: [p1, p2]} do
      Feeds.activate_session(p1.user_id, 60, @reference)
      Feeds.activate_session(p2.user_id, 60, @reference)

      assert true == Feeds.invite_active_user(p1.user_id, p2.user_id)

      assert [
               {%FeedProfile{} = feed_profile,
                %ActiveSession{expires_at: ~U[2021-07-21 12:55:18Z]}}
             ] = Feeds.list_received_invites(p2.user_id)

      assert feed_profile.user_id == p1.user_id

      assert true == Feeds.deactivate_session(p2.user_id)
      assert [] == Feeds.list_received_invites(p2.user_id)
    end
  end

  describe "fetch_feed/3" do
    setup do
      me = insert(:profile)
      {:ok, me: me}
    end

    test "with no data in db", %{me: me} do
      assert {[], nil} == Feeds.fetch_feed(me.user_id, _count = 10, _cursor = nil)
    end

    test "with no active users", %{me: me} do
      insert_list(3, :profile)
      assert {[], nil} == Feeds.fetch_feed(me.user_id, _count = 10, _cursor = nil)
    end

    test "with active users fewer than count", %{me: me} do
      others = insert_list(3, :profile)
      activate_sessions(others, @reference)

      assert {[
                {%FeedProfile{}, %ActiveSession{expires_at: ~U[2021-07-21 12:55:18Z]}},
                {%FeedProfile{}, %ActiveSession{expires_at: ~U[2021-07-21 12:55:18Z]}},
                {%FeedProfile{},
                 %ActiveSession{flake: cursor, expires_at: ~U[2021-07-21 12:55:18Z]}}
              ], cursor} = Feeds.fetch_feed(me.user_id, _count = 10, _cursor = nil)

      assert {[], ^cursor} = Feeds.fetch_feed(me.user_id, _count = 10, cursor)
    end

    test "with active users more than count", %{me: me} do
      others = insert_list(3, :profile)
      activate_sessions(others, @reference)

      assert {[
                {%FeedProfile{}, %ActiveSession{expires_at: ~U[2021-07-21 12:55:18Z]}},
                {%FeedProfile{},
                 %ActiveSession{flake: cursor1, expires_at: ~U[2021-07-21 12:55:18Z]}}
              ], cursor1} = Feeds.fetch_feed(me.user_id, _count = 2, _cursor = nil)

      assert {[
                {%FeedProfile{},
                 %ActiveSession{flake: cursor2, expires_at: ~U[2021-07-21 12:55:18Z]}}
              ], cursor2} = Feeds.fetch_feed(me.user_id, _count = 10, cursor1)

      assert cursor2 != cursor1

      assert {[], ^cursor2} = Feeds.fetch_feed(me.user_id, _count = 10, cursor2)
    end
  end

  describe "get_feed_item/1" do
    setup do
      me = insert(:user)
      other = insert(:profile)
      activate_session(other, @reference)
      {:ok, me: me, other: other}
    end

    test "returns non reported user", %{me: me, other: other} do
      assert {%FeedProfile{}, %ActiveSession{expires_at: ~U[2021-07-21 12:55:18Z]}} =
               Feeds.get_feed_item(me.id, other.user_id)
    end

    test "doesn't return reported user", %{me: me, other: other} do
      assert :ok = Accounts.report_user(me.id, other.user_id, "ugly")
      refute Feeds.get_feed_item(me.id, other.user_id)
    end
  end
end
