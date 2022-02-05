defmodule T.FeedsLiveTest do
  use T.DataCase
  use Oban.Testing, repo: T.Repo

  alias T.Feeds
  alias T.Feeds.{LiveSession, LiveInvite, FeedFilter}
  alias T.Accounts

  import Mox
  setup :verify_on_exit!

  describe "live_now?/1" do
    test "Thursday" do
      refute Feeds.live_now?(msk(~D[2021-12-09], ~T[18:59:59]))

      assert Feeds.live_now?(msk(~D[2021-12-09], ~T[19:00:00]))
      assert Feeds.live_now?(msk(~D[2021-12-09], ~T[19:00:01]))
      assert Feeds.live_now?(msk(~D[2021-12-09], ~T[20:59:59]))
      assert Feeds.live_now?(msk(~D[2021-12-09], ~T[21:00:00]))

      refute Feeds.live_now?(msk(~D[2021-12-09], ~T[21:00:01]))
    end

    test "Saturday" do
      refute Feeds.live_now?(msk(~D[2021-12-11], ~T[19:59:59]))

      assert Feeds.live_now?(msk(~D[2021-12-11], ~T[20:00:00]))
      assert Feeds.live_now?(msk(~D[2021-12-11], ~T[20:00:01]))
      assert Feeds.live_now?(msk(~D[2021-12-11], ~T[21:59:59]))
      assert Feeds.live_now?(msk(~D[2021-12-11], ~T[22:00:00]))

      refute Feeds.live_now?(msk(~D[2021-12-11], ~T[22:00:01]))
    end

    test "Monday" do
      refute Feeds.live_now?(msk(~D[2021-12-06], ~T[18:00:00]))
      refute Feeds.live_now?(msk(~D[2021-12-06], ~T[19:00:00]))
      refute Feeds.live_now?(msk(~D[2021-12-06], ~T[20:00:00]))
      refute Feeds.live_now?(msk(~D[2021-12-06], ~T[21:00:00]))
      refute Feeds.live_now?(msk(~D[2021-12-06], ~T[22:00:00]))
    end
  end

  describe "live_mode_start/0" do
    test "notifies :mode_change subscribers" do
      Feeds.subscribe_for_mode_change()
      :ok = Feeds.live_mode_start()
      assert_receive {Feeds, [:mode_change, :start]}
    end

    test "schedules push notifications with 'starting' message" do
      insert(:apns_device, user: build(:user), device_id: Base.decode16!("BABA"))
      insert(:apns_device, user: build(:user), device_id: Base.decode16!("ABAB"), locale: "ru")

      :ok = Feeds.live_mode_start()

      assert [
               %{"device_id" => "ABAB", "template" => "live_mode_started"},
               %{"device_id" => "BABA", "template" => "live_mode_started"}
             ] = Enum.map(all_enqueued(), & &1.args)

      expected_alerts = %{
        "BABA" => %{
          "title" => "Since Live starts 🥳",
          "body" => "Come to the party and chat 🎉"
        },
        "ABAB" => %{
          "title" => "Since Live начинается 🥳",
          "body" => "Заходи на вечеринку и общайся 🎉"
        }
      }

      expect(MockAPNS, :push, 2, fn %{device_id: device_id, payload: payload} ->
        assert expected_alerts[device_id] == payload["aps"]["alert"]
        :ok
      end)

      assert %{failure: 0, snoozed: 0, success: 2} =
               Oban.drain_queue(queue: :apns, with_safety: false)
    end
  end

  describe "live_mode_end/0,1" do
    test "broadcasts end event to all subcribers" do
      :ok = Feeds.subscribe_for_mode_change()
      :ok = Feeds.live_mode_end()
      assert_receive {Feeds, [:mode_change, :end]}
    end

    # TODO
    @tag skip: true
    test "clears live tables"

    test "schedules push notifications with the next live event" do
      insert(:apns_device, user: build(:user), device_id: Base.decode16!("BABA"))
      insert(:apns_device, user: build(:user), device_id: Base.decode16!("ABAB"), locale: "ru")

      :ok = Feeds.live_mode_end(msk(~D[2021-12-19], ~T[20:00:00]))

      assert [
               %{
                 "device_id" => "ABAB",
                 "template" => "live_mode_ended",
                 "data" => %{"next" => "2021-12-23"}
               },
               %{
                 "device_id" => "BABA",
                 "template" => "live_mode_ended",
                 "data" => %{"next" => "2021-12-23"}
               }
             ] = Enum.map(all_enqueued(), & &1.args)

      expected_alerts = %{
        "BABA" => %{
          "title" => "Since Live ended ✌️",
          "body" => "Wait for the party on Thursday 👀"
        },
        "ABAB" => %{
          "title" => "Since Live закончился ✌️",
          "body" => "Жди следующую вечеринку в четверг 👀"
        }
      }

      expect(MockAPNS, :push, 2, fn %{device_id: device_id, payload: payload} ->
        assert expected_alerts[device_id] == payload["aps"]["alert"]
        :ok
      end)

      assert %{failure: 0, snoozed: 0, success: 2} =
               Oban.drain_queue(queue: :apns, with_safety: false)
    end
  end

  describe "maybe_activate_session/1" do
    setup do
      me = onboarded_user(location: moscow_location())
      {:ok, me: me}
    end

    test "side-effects", %{me: me} do
      Feeds.maybe_activate_session(me.id, me.profile.gender, %FeedFilter{genders: ["M", "N", "F"]})

      assert LiveSession |> select([s], s.user_id) |> Repo.all() == [me.id]
    end

    test "match is notified properly", %{me: me} do
      mate = onboarded_user()

      insert(:match, user_id_1: me.id, user_id_2: mate.id)

      Feeds.maybe_activate_session(me.id, me.profile.gender, %FeedFilter{genders: ["M", "N", "F"]})

      assert [
               %Oban.Job{
                 args: %{
                   "type" => "match_went_live",
                   "user_id" => uid1,
                   "for_user_id" => uid2
                 }
               }
             ] = all_enqueued(worker: T.PushNotifications.DispatchJob)

      assert uid1 == me.id
      assert uid2 == mate.id

      Feeds.maybe_activate_session(me.id, me.profile.gender, %FeedFilter{genders: ["M", "N", "F"]})

      assert [_] = all_enqueued(worker: T.PushNotifications.DispatchJob)
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

      ls1 = Feeds.maybe_activate_session(p1.user_id, p1.gender, want_f)

      assert Feeds.fetch_live_feed(p1.user_id, p1.gender, want_f, 10, nil) == {[], nil}

      # p2 comes in, gets p1 in feed

      ls2 = Feeds.maybe_activate_session(p2.user_id, p2.gender, want_fm)

      assert {[feed_profile], cursor} =
               Feeds.fetch_live_feed(p2.user_id, p2.gender, want_fm, 10, nil)

      assert feed_profile.user_id == p1.user_id
      assert cursor == ls1.flake

      # p3 comes in, gets p1 and p2 in feed

      _ls3 = Feeds.maybe_activate_session(p3.user_id, p3.gender, want_fm)

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

      Feeds.maybe_activate_session(
        f_want_f.user_id,
        f_want_f.gender,
        %Feeds.FeedFilter{genders: ["F"]}
      )

      me = insert(:profile, gender: "M", hidden?: false)
      want_f = %Feeds.FeedFilter{genders: ["F"]}

      Feeds.maybe_activate_session(me.user_id, me.gender, want_f)

      assert {_feed = [], _cursor = nil} =
               Feeds.fetch_live_feed(me.user_id, me.gender, want_f, _count = 10, _cursor = nil)
    end

    test "doesn't return profiles who I'm not interested in" do
      f_want_m = insert(:profile, gender: "F", hidden?: false)
      insert(:gender_preference, user_id: f_want_m.user_id, gender: "M")

      want_m = %Feeds.FeedFilter{genders: ["M"]}

      Feeds.maybe_activate_session(f_want_m.user_id, f_want_m.gender, want_m)

      me = insert(:profile, gender: "M", hidden?: false)

      Feeds.maybe_activate_session(f_want_m.user_id, f_want_m.gender, want_m)

      assert {_feed = [], _cursor = nil} =
               Feeds.fetch_live_feed(me.user_id, me.gender, want_m, _count = 10, _cursor = nil)
    end

    test "return profiles with mutual interest" do
      f_want_m = insert(:profile, gender: "F", hidden?: false)
      insert(:gender_preference, user_id: f_want_m.user_id, gender: "M")

      f_want_m_session =
        Feeds.maybe_activate_session(
          f_want_m.user_id,
          f_want_m.gender,
          %Feeds.FeedFilter{genders: ["M"]}
        )

      me = insert(:profile, gender: "M", hidden?: false)
      want_f = %Feeds.FeedFilter{genders: ["F"]}

      Feeds.maybe_activate_session(me.user_id, me.gender, want_f)

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

      _ls1 =
        Feeds.maybe_activate_session(
          p1.user_id,
          p1.gender,
          %FeedFilter{genders: ["F", "M", "N"]}
        )

      _ls2 =
        Feeds.maybe_activate_session(
          p2.user_id,
          p2.gender,
          %FeedFilter{genders: ["F", "M", "N"]}
        )

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
      _ls1 =
        Feeds.maybe_activate_session(
          p1.user_id,
          p1.gender,
          %FeedFilter{genders: ["F", "M", "N"]}
        )

      _ls2 =
        Feeds.maybe_activate_session(
          p2.user_id,
          p2.gender,
          %FeedFilter{genders: ["F", "M", "N"]}
        )

      Accounts.report_user(p2.user_id, p1.user_id, "default")

      Feeds.live_invite_user(p1.user_id, p2.user_id)

      assert LiveInvite |> Repo.all() == []
    end

    test "by hidden user", %{profiles: [p1, _p2, p3]} do
      _ls1 =
        Feeds.maybe_activate_session(
          p1.user_id,
          p1.gender,
          %FeedFilter{genders: ["F", "M", "N"]}
        )

      _ls3 =
        Feeds.maybe_activate_session(
          p3.user_id,
          p3.gender,
          %FeedFilter{genders: ["F", "M", "N"]}
        )

      Feeds.live_invite_user(p3.user_id, p1.user_id)

      assert LiveInvite |> Repo.all() == []
    end
  end
end
