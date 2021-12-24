defmodule T.Feeds.NewbiesLiveTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: Repo
  alias T.Feeds

  @oldies Application.fetch_env!(:t, :oldies)
  false = Enum.empty?(@oldies)

  import Mox
  setup :verify_on_exit!

  describe "newbies_list_today_participants/0,1" do
    # this is a bad test since ideally we won't be running
    # "Since Live for newbies" with no newbies attending
    test "lists oldies if no newbies" do
      assert Feeds.newbies_list_today_participants() == @oldies
    end

    test "doesn't list blocked newbies" do
      newbie_user(
        onboarded_at: msk(~D[2021-12-19], ~T[09:47:57]),
        blocked_at: msk(~D[2021-12-19], ~T[12:49:00])
      )

      assert Feeds.newbies_list_today_participants(_now = msk(~D[2021-12-19], ~T[13:00:00])) ==
               @oldies
    end

    test "correctly lists today's participants" do
      %{id: _} = newbie_user(onboarded_at: msk(~D[2021-12-19], ~T[12:00:00]))
      %{id: _} = newbie_user(onboarded_at: msk(~D[2021-12-19], ~T[14:00:00]))
      %{id: _} = newbie_user(onboarded_at: msk(~D[2021-12-19], ~T[18:59:59]))
      %{id: _yesterday_19_00} = newbie_user(onboarded_at: msk(~D[2021-12-19], ~T[19:00:00]))
      %{id: _yesterday_20_00} = newbie_user(onboarded_at: msk(~D[2021-12-19], ~T[20:00:00]))
      %{id: yesterday_20_00_01} = newbie_user(onboarded_at: msk(~D[2021-12-19], ~T[20:00:01]))
      %{id: today_12_00} = newbie_user(onboarded_at: msk(~D[2021-12-20], ~T[12:00:00]))

      # "Since Live is today" notification is sent at 13:00 MSK
      participants = Feeds.newbies_list_today_participants(msk(~D[2021-12-20], ~T[13:00:00]))

      assert_lists_equal(participants, [
        yesterday_20_00_01,
        today_12_00 | @oldies
      ])

      # more users
      %{id: today_18_40} = newbie_user(onboarded_at: msk(~D[2021-12-20], ~T[18:40:00]))

      # "Since Live is soon" notification is sent at 18:45 MSK
      participants = Feeds.newbies_list_today_participants(msk(~D[2021-12-20], ~T[18:45:00]))

      assert_lists_equal(participants, [
        yesterday_20_00_01,
        today_12_00,
        today_18_40 | @oldies
      ])

      # more users
      %{id: today_18_59} = newbie_user(onboarded_at: msk(~D[2021-12-20], ~T[18:59:59]))
      %{id: today_19_00} = newbie_user(onboarded_at: msk(~D[2021-12-20], ~T[19:00:00]))

      # event starts at 19:00 MSK
      participants = Feeds.newbies_list_today_participants(msk(~D[2021-12-20], ~T[19:00:00]))

      assert_lists_equal(participants, [
        yesterday_20_00_01,
        today_12_00,
        today_18_40,
        today_18_59,
        today_19_00 | @oldies
      ])
    end
  end

  describe "live_now?/1,2" do
    test "returns false when no ongoing event and user is participant" do
      oldie = List.first(@oldies)
      %{id: newbie} = newbie_user(onboarded_at: msk(~D[2021-12-19], ~T[09:47:57]))

      for time <- [~T[18:59:59], ~T[20:00:01]], user <- [oldie, newbie] do
        refute Feeds.live_now?(user, msk(~D[2021-12-19], time), _newbies_live_enabled? = true)
      end
    end

    test "returns true when ongoing event and user is participant" do
      oldie = List.first(@oldies)
      %{id: newbie} = newbie_user(onboarded_at: msk(~D[2021-12-19], ~T[09:47:57]))

      users = [oldie, newbie]
      times = [~T[19:00:00], ~T[19:00:01], ~T[19:59:59], ~T[20:00:00]]

      for time <- times, user <- users do
        assert Feeds.live_now?(user, msk(~D[2021-12-19], time), _newbies_live_enabled? = true)
      end
    end

    test "returns false when user is not participant" do
      %{id: old} = newbie_user(onboarded_at: msk(~D[2021-12-01], ~T[18:59:59]))
      times = [~T[18:59:59], ~T[19:00:00], ~T[19:59:59], ~T[20:00:00], ~T[20:00:01]]

      for time <- times do
        refute Feeds.live_now?(old, msk(~D[2021-12-19], time), _newbies_live_enabled? = true)
      end
    end
  end

  describe "newbies_start_live/0,1" do
    setup do
      {:ok, newbie: newbie_user(onboarded_at: msk(~D[2021-12-19], ~T[09:47:57]))}
    end

    test "notifies feed:<user-id> subscribers", %{newbie: newbie} do
      :ok = Phoenix.PubSub.subscribe(T.PubSub, "feed:" <> List.first(@oldies))
      :ok = Phoenix.PubSub.subscribe(T.PubSub, "feed:" <> newbie.id)

      :ok = Feeds.newbies_start_live(_now = msk(~D[2021-12-19], ~T[19:00:00]))

      assert_receive {Feeds, [:mode_change, :start]}
      assert_receive {Feeds, [:mode_change, :start]}
    end

    test "schedules push notifications with 'starting' message", %{newbie: newbie} do
      insert(:apns_device, user: newbie, device_id: Base.decode16!("BABABABABA"))
      insert(:apns_device, user: newbie, device_id: Base.decode16!("ABABABAB"), locale: "ru")

      :ok = Feeds.newbies_start_live(_now = msk(~D[2021-12-19], ~T[19:00:00]))

      assert [
               %{"device_id" => "ABABABAB", "template" => "newbie_live_mode_started"},
               %{"device_id" => "BABABABABA", "template" => "newbie_live_mode_started"}
             ] = Enum.map(all_enqueued(), & &1.args)

      expected_alerts = %{
        "BABABABABA" => %{
          "title" => "Since Live starts 🥳",
          "body" => "Only you and other new users are invited 🎉"
        },
        "ABABABAB" => %{
          "title" => "Since Live начинается 🥳",
          "body" => "Приглашены все новички 🎉"
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

  describe "newbies_end_live/0" do
    test "broadcasts end event to all subcribers" do
      :ok = Feeds.subscribe_for_mode_change()
      :ok = Feeds.newbies_end_live()
      assert_receive {Feeds, [:mode_change, :end]}
    end

    # TODO
    @tag skip: true
    test "clears live tables"

    test "schedules push notifications with the next real live event" do
      newbie = newbie_user(onboarded_at: msk(~D[2021-12-19], ~T[09:47:57]))
      insert(:apns_device, user: newbie, device_id: Base.decode16!("BABABABABA"))
      insert(:apns_device, user: newbie, device_id: Base.decode16!("ABABABAB"), locale: "ru")

      :ok = Feeds.newbies_end_live(msk(~D[2021-12-19], ~T[20:00:00]))

      assert [
               %{
                 "device_id" => "ABABABAB",
                 "template" => "newbie_live_mode_ended",
                 "data" => %{"next" => "2021-12-23"}
               },
               %{
                 "device_id" => "BABABABABA",
                 "template" => "newbie_live_mode_ended",
                 "data" => %{"next" => "2021-12-23"}
               }
             ] = Enum.map(all_enqueued(), & &1.args)

      expected_alerts = %{
        "BABABABABA" => %{
          "title" => "Since Live for newbies is over ✌️",
          "body" => "Wait for the real party on Thursday 👀"
        },
        "ABABABAB" => %{
          "title" => "Since Live для новеньких закончился ✌️",
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

  defp newbie_user(opts) do
    opts =
      if onboarded_at = opts[:onboarded_at] do
        Keyword.put_new(opts, :onboarded_with_story_at, onboarded_at)
      else
        opts
      end

    _profile = %{user: user} = insert(:profile, hidden?: false, user: build(:user, opts))
    user
  end
end
