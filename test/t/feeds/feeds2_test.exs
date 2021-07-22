defmodule T.Feeds2Test do
  use T.DataCase, async: true
  use Oban.Testing, repo: T.Repo

  alias T.Accounts.{User, Profile}
  alias T.Feeds.{ActiveSession, FeedProfile}
  alias T.{Feeds2, Accounts}
  alias T.Invites.CallInvite
  alias T.PushNotifications.DispatchJob

  describe "activate_session/2" do
    test "doesn't raise on conflict, latest session takes precedence" do
      user = insert(:user)
      reference = ~U[2021-07-21 10:55:18.941048Z]

      assert %ActiveSession{expires_at: ~U[2021-07-21 11:55:18Z]} =
               Feeds2.activate_session(user.id, _hour = 60, reference)

      # TODO what happens with invites? right now they are probably all deleted
      assert %ActiveSession{expires_at: ~U[2021-07-21 11:15:18Z]} =
               Feeds2.activate_session(user.id, _20_mins = 20, reference)

      assert %ActiveSession{expires_at: ~U[2021-07-21 11:15:18Z]} =
               Feeds2.get_current_session(user.id)
    end
  end

  describe "expired sessions" do
    @reference ~U[2021-07-21 11:55:18.941048Z]

    setup do
      [u1, u2, u3] = users = insert_list(3, :user)

      Feeds2.activate_session(u1.id, 60, _reference = ~U[2021-07-21 10:50:18Z])
      Feeds2.activate_session(u2.id, 60, _reference = ~U[2021-07-21 10:53:18Z])
      Feeds2.activate_session(u3.id, 60, _reference = ~U[2021-07-21 10:56:18Z])

      {:ok, users: users}
    end

    test "expired_sessions/0 returns expired sessions" do
      assert [
               %ActiveSession{expires_at: ~U[2021-07-21 11:50:18Z]},
               %ActiveSession{expires_at: ~U[2021-07-21 11:53:18Z]}
             ] = Feeds2.expired_sessions(@reference)
    end

    test "delete_expired_sessions/0 deletes expired sessions" do
      assert {2, nil} == Feeds2.delete_expired_sessions(@reference)
      assert [] == Feeds2.expired_sessions(@reference)
    end
  end

  describe "invite_active_user/2" do
    setup do
      [u1, u2] = users = insert_list(2, :user)

      :ok = Feeds2.subscribe_for_invites(u1.id)
      :ok = Feeds2.subscribe_for_invites(u2.id)

      {:ok, users: users}
    end

    test "when both users not active", %{users: [u1, u2]} do
      assert false == Feeds2.invite_active_user(u1.id, u2.id)

      assert [] = all_enqueued(worder: DispatchJob)
      refute_receive _anything
    end

    test "when inviter is not active", %{users: [u1, u2]} do
      Feeds2.activate_session(u2.id, 60)

      assert false == Feeds2.invite_active_user(u1.id, u2.id)

      assert [] = all_enqueued(worder: DispatchJob)
      refute_receive _anything
    end

    test "when invitee is not active", %{users: [u1, u2]} do
      Feeds2.activate_session(u1.id, 60)

      assert false == Feeds2.invite_active_user(u1.id, u2.id)

      assert [] = all_enqueued(worder: DispatchJob)
      refute_receive _anything
    end

    test "when both users are active", %{users: [%{id: u1_id}, %{id: u2_id}]} do
      Feeds2.activate_session(u1_id, 60)
      Feeds2.activate_session(u2_id, 60)

      assert true == Feeds2.invite_active_user(u1_id, u2_id)

      assert [%Oban.Job{args: %{"type" => "invite", "by_user_id" => ^u1_id, "user_id" => ^u2_id}}] =
               all_enqueued(worder: DispatchJob)

      assert_receive {Feeds2, :invited, ^u1_id}
      refute_receive _anything_else
    end

    test "no duplicate notifications on duplicate invite", %{users: [u1, u2]} do
      Feeds2.activate_session(u1.id, 60)
      Feeds2.activate_session(u2.id, 60)

      assert true == Feeds2.invite_active_user(u1.id, u2.id)
      assert false == Feeds2.invite_active_user(u1.id, u2.id)

      assert [%Oban.Job{}] = all_enqueued(worder: DispatchJob)

      assert_receive {Feeds2, :invited, _by_user_id}
      refute_receive _anything_else
    end

    # TODO delete invite when either user is reported by the other
    # TODO delete active session when user gets hidden
    @tag skip: true
    test "when inviter is reported by invitee"
  end

  describe "deactivate_session/1" do
    setup do
      [u1, u2] = users = insert_list(2, :user)

      :ok = Feeds2.subscribe_for_invites(u1.id)
      :ok = Feeds2.subscribe_for_invites(u2.id)

      {:ok, users: users}
    end

    test "invites are cleared when session is deactivated for inviter", %{users: [u1, u2]} do
      Feeds2.activate_session(u1.id, 60)
      Feeds2.activate_session(u2.id, 60)
      assert true == Feeds2.invite_active_user(u1.id, u2.id)
      assert [%CallInvite{}] = Feeds2.list_received_invites(u2.id)

      assert true == Feeds2.deactivate_session(u1.id)

      assert [] == Feeds2.list_received_invites(u2.id)
    end

    test "invites are cleared when session is deactivated for invitee", %{users: [u1, u2]} do
      Feeds2.activate_session(u1.id, 60)
      Feeds2.activate_session(u2.id, 60)
      assert true == Feeds2.invite_active_user(u1.id, u2.id)
      assert [%CallInvite{}] = Feeds2.list_received_invites(u2.id)

      assert true == Feeds2.deactivate_session(u2.id)

      assert [] == Feeds2.list_received_invites(u2.id)
    end
  end

  describe "fetch_feed/3" do
    setup do
      me = insert(:profile)
      {:ok, me: me}
    end

    test "with no data in db", %{me: me} do
      assert {[], nil} == Feeds2.fetch_feed(me.user_id, _count = 10, _cursor = nil)
    end

    test "with no active users", %{me: me} do
      insert_list(3, :profile)
      assert {[], nil} == Feeds2.fetch_feed(me.user_id, _count = 10, _cursor = nil)
    end

    test "with active users fewer than count", %{me: me} do
      others = insert_list(3, :profile)
      activate_sessions(others, @reference)

      assert {[
                {%FeedProfile{}, _expires_at = ~U[2021-07-21 12:55:18Z]},
                {%FeedProfile{}, ~U[2021-07-21 12:55:18Z]},
                {%FeedProfile{}, ~U[2021-07-21 12:55:18Z]}
              ], cursor} = Feeds2.fetch_feed(me.user_id, _count = 10, _cursor = nil)

      assert {[], ^cursor} = Feeds2.fetch_feed(me.user_id, _count = 10, cursor)
    end

    test "with active users more than count", %{me: me} do
      others = insert_list(3, :profile)
      activate_sessions(others, @reference)

      assert {[
                {%FeedProfile{}, _expires_at = ~U[2021-07-21 12:55:18Z]},
                {%FeedProfile{}, ~U[2021-07-21 12:55:18Z]}
              ], cursor1} = Feeds2.fetch_feed(me.user_id, _count = 2, _cursor = nil)

      assert {[{%FeedProfile{}, ~U[2021-07-21 12:55:18Z]}], cursor2} =
               Feeds2.fetch_feed(me.user_id, _count = 10, cursor1)

      assert cursor2 != cursor1

      assert {[], ^cursor2} = Feeds2.fetch_feed(me.user_id, _count = 10, cursor2)
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
      assert {%FeedProfile{}, _expires_at = ~U[2021-07-21 12:55:18Z]} =
               Feeds2.get_feed_item(me.id, other.user_id)
    end

    test "doesn't return reported user", %{me: me, other: other} do
      assert :ok = Accounts.report_user(me.id, other.user_id, "ugly")
      refute Feeds2.get_feed_item(me.id, other.user_id)
    end
  end
end
