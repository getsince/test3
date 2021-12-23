defmodule T.FeedsLiveTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: T.Repo

  alias T.Feeds
  alias T.Feeds.{LiveSession, LiveInvite}
  alias T.Accounts

  describe "is_now_live_mode/2" do
    test "Thursday" do
      assert Feeds.is_now_live_mode(Date.new!(2021, 12, 9), Time.new!(17, 0, 0)) == true
      assert Feeds.is_now_live_mode(Date.new!(2021, 12, 9), Time.new!(18, 0, 0)) == false
    end

    test "Saturday" do
      assert Feeds.is_now_live_mode(Date.new!(2021, 12, 11), Time.new!(17, 0, 0)) == true
      assert Feeds.is_now_live_mode(Date.new!(2021, 12, 11), Time.new!(19, 0, 0)) == false
    end

    test "Monday" do
      assert Feeds.is_now_live_mode(Date.new!(2021, 12, 6), Time.new!(17, 0, 0)) == false
      assert Feeds.is_now_live_mode(Date.new!(2021, 12, 6), Time.new!(18, 0, 0)) == false
    end
  end

  describe "maybe_activate_session/1" do
    setup do
      me = onboarded_user(location: moscow_location())
      {:ok, me: me}
    end

    test "side-effects", %{me: me} do
      Feeds.maybe_activate_session(me.id)
      assert LiveSession |> select([s], s.user_id) |> Repo.all() == [me.id]
    end

    test "match is notified properly" do
      [p1, p2] = insert_list(2, :profile, hidden?: false)

      insert(:match, user_id_1: p1.user_id, user_id_2: p2.user_id)

      Feeds.maybe_activate_session(p1.user_id)

      assert [
               %Oban.Job{
                 args: %{
                   "type" => "match_went_live",
                   "user_id" => uid1,
                   "for_user_id" => uid2
                 }
               }
             ] = all_enqueued(worker: T.PushNotifications.DispatchJob)

      assert uid1 == p1.user_id
      assert uid2 == p2.user_id

      Feeds.maybe_activate_session(p1.user_id)

      assert length(all_enqueued(worker: T.PushNotifications.DispatchJob)) == 1
    end
  end

  describe "fetch_live_feed/3" do
    test "normal" do
      p1 = insert(:profile, gender: "M", hidden?: false)
      insert(:gender_preference, user_id: p1.user_id, gender: "F")

      p2 = insert(:profile, gender: "F", hidden?: false)
      insert(:gender_preference, user_id: p2.user_id, gender: "F")
      insert(:gender_preference, user_id: p2.user_id, gender: "M")

      p3 = insert(:profile, gender: "F", hidden?: false)
      insert(:gender_preference, user_id: p3.user_id, gender: "F")
      insert(:gender_preference, user_id: p3.user_id, gender: "M")

      want_fm = %Feeds.FeedFilter{genders: ["F", "M"]}
      want_f = %Feeds.FeedFilter{genders: ["F"]}

      # p1 activates a session, nobody in, so feed is empty

      ls1 = Feeds.maybe_activate_session(p1.user_id)
      assert Feeds.fetch_live_feed(p1.user_id, p1.gender, want_f, 10, nil) == {[], nil}

      # p2 comes in, gets p1 in feed

      ls2 = Feeds.maybe_activate_session(p2.user_id)

      assert {[feed_profile], cursor} =
               Feeds.fetch_live_feed(p2.user_id, p2.gender, want_fm, 10, nil)

      assert feed_profile.user_id == p1.user_id
      assert cursor == ls1.flake

      # p3 comes in, gets p1 and p2 in feed

      _ls3 = Feeds.maybe_activate_session(p3.user_id)
      assert {[fp1, fp2], cursor} = Feeds.fetch_live_feed(p3.user_id, p3.gender, want_fm, 10, nil)

      assert fp1.user_id == p1.user_id
      assert fp2.user_id == p2.user_id
      assert cursor == ls2.flake

      # feed's ended

      assert Feeds.fetch_live_feed(p3.user_id, p3.gender, want_fm, 10, cursor) == {[], cursor}
    end

    test "doesn't return profiles who are not interested in me" do
      f_want_f = insert(:profile, gender: "F", hidden?: false)
      insert(:gender_preference, user_id: f_want_f.user_id, gender: "F")
      Feeds.maybe_activate_session(f_want_f.user_id)

      me = insert(:profile, gender: "M", hidden?: false)
      want_f = %Feeds.FeedFilter{genders: ["F"]}
      Feeds.maybe_activate_session(me.user_id)

      assert {_feed = [], _cursor = nil} =
               Feeds.fetch_live_feed(me.user_id, me.gender, want_f, _count = 10, _cursor = nil)
    end

    test "doesn't return profiles who I'm not interested in" do
      f_want_m = insert(:profile, gender: "F", hidden?: false)
      insert(:gender_preference, user_id: f_want_m.user_id, gender: "M")
      Feeds.maybe_activate_session(f_want_m.user_id)

      me = insert(:profile, gender: "M", hidden?: false)
      want_m = %Feeds.FeedFilter{genders: ["M"]}
      Feeds.maybe_activate_session(me.user_id)

      assert {_feed = [], _cursor = nil} =
               Feeds.fetch_live_feed(me.user_id, me.gender, want_m, _count = 10, _cursor = nil)
    end

    test "return profiles with mutual interest" do
      f_want_m = insert(:profile, gender: "F", hidden?: false)
      insert(:gender_preference, user_id: f_want_m.user_id, gender: "M")
      f_want_m_session = Feeds.maybe_activate_session(f_want_m.user_id)

      me = insert(:profile, gender: "M", hidden?: false)
      want_f = %Feeds.FeedFilter{genders: ["F"]}
      Feeds.maybe_activate_session(me.user_id)

      assert {_feed = [profile], cursor} =
               Feeds.fetch_live_feed(me.user_id, me.gender, want_f, _count = 10, _cursor = nil)

      assert profile.user_id == f_want_m.user_id
      assert cursor == f_want_m_session.flake
    end
  end

  describe "live_invite_user/2" do
    setup do
      [p1, p2] = insert_list(2, :profile, hidden?: false)
      p3 = insert(:profile, hidden?: true)
      {:ok, profiles: [p1, p2, p3]}
    end

    test "with side-effects", %{profiles: [p1, p2, _p3]} do
      assert_raise Ecto.ConstraintError, fn -> Feeds.live_invite_user(p1.user_id, p2.user_id) end

      _ls1 = Feeds.maybe_activate_session(p1.user_id)
      _ls2 = Feeds.maybe_activate_session(p2.user_id)

      :ok = Feeds.subscribe_for_user(p2.user_id)

      Feeds.live_invite_user(p1.user_id, p2.user_id)

      assert LiveInvite |> select([s], {s.by_user_id, s.user_id}) |> Repo.all() == [
               {p1.user_id, p2.user_id}
             ]

      assert_receive {Feeds, :live_invited, %{by_user_id: by_user_id}}
      assert by_user_id == p1.user_id

      assert [
               %Oban.Job{
                 args: %{
                   "type" => "live_invite",
                   "by_user_id" => by_user_id,
                   "user_id" => user_id
                 }
               }
             ] = all_enqueued(worker: T.PushNotifications.DispatchJob)

      assert by_user_id == p1.user_id
      assert user_id == p2.user_id
    end

    test "by reported user", %{profiles: [p1, p2, _p3]} do
      _ls1 = Feeds.maybe_activate_session(p1.user_id)
      _ls2 = Feeds.maybe_activate_session(p2.user_id)

      Accounts.report_user(p2.user_id, p1.user_id, "default")

      Feeds.live_invite_user(p1.user_id, p2.user_id)

      assert LiveInvite |> Repo.all() == []
    end

    test "by hidden user", %{profiles: [p1, _p2, p3]} do
      _ls1 = Feeds.maybe_activate_session(p1.user_id)
      _ls3 = Feeds.maybe_activate_session(p3.user_id)

      Feeds.live_invite_user(p3.user_id, p1.user_id)

      assert LiveInvite |> Repo.all() == []
    end
  end
end
