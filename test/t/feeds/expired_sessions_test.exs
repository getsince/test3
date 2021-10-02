defmodule T.Feeds.ExpiredSessionsTest do
  use T.DataCase
  use Oban.Testing, repo: T.Repo

  import Assertions

  alias T.{Feeds, Accounts}
  alias T.APNS.{DispatchJob, APNSJob}
  alias Feeds.ActiveSession

  import Mox
  setup :verify_on_exit!

  @reference ~U[2021-07-21 11:55:18.941048Z]

  setup do
    [u1, u2, u3] = users = insert_list(3, :user)

    Feeds.activate_session(u1.id, 60, _reference = ~U[2021-07-21 10:50:18Z])
    Feeds.activate_session(u2.id, 60, _reference = ~U[2021-07-21 10:53:18Z])
    Feeds.activate_session(u3.id, 60, _reference = ~U[2021-07-21 10:56:18Z])

    {:ok, users: users}
  end

  describe "expired_sessions/0" do
    test "expired_sessions/0 returns expired sessions" do
      assert [
               %ActiveSession{expires_at: ~U[2021-07-21 11:50:18Z]},
               %ActiveSession{expires_at: ~U[2021-07-21 11:53:18Z]}
             ] = Feeds.expired_sessions(@reference)
    end
  end

  describe "delete_expired_sessions/0" do
    test "deletes expired sessions and schedules notifications", %{
      users: [%{id: u1}, %{id: u2}, _u3]
    } do
      assert {2, [u1, u2]} == Feeds.delete_expired_sessions(@reference)
      assert [] == Feeds.expired_sessions(@reference)

      :ok =
        Accounts.save_apns_device_id(
          u1,
          u1
          |> Accounts.generate_user_session_token("mobile")
          |> Accounts.UserToken.encoded_token(),
          Base.decode16!("BABABABABA"),
          env: "sandbox",
          locale: "en"
        )

      :ok =
        Accounts.save_apns_device_id(
          u2,
          u2
          |> Accounts.generate_user_session_token("mobile")
          |> Accounts.UserToken.encoded_token(),
          Base.decode16!("ABABABABAB"),
          env: "sandbox",
          locale: "ru"
        )

      # verify dispatch scheduled

      assert [
               %Oban.Job{args: %{"type" => "session_expired", "user_id" => ^u2}, queue: "apns"},
               %Oban.Job{args: %{"type" => "session_expired", "user_id" => ^u1}, queue: "apns"}
             ] = all_enqueued(worder: DispatchJob)

      assert %{failure: 0, success: 2} = Oban.drain_queue(queue: :apns)

      # verify apns scheduled

      expected_apns_jobs = [
        %{
          "data" => %{},
          "device_id" => "ABABABABAB",
          "env" => "sandbox",
          "locale" => "ru",
          "template" => "session_expired",
          "topic" => "app.topic"
        },
        %{
          "data" => %{},
          "device_id" => "BABABABABA",
          "env" => "sandbox",
          "locale" => "en",
          "template" => "session_expired",
          "topic" => "app.topic"
        }
      ]

      actual_apns_jobs = all_enqueued(worker: APNSJob) |> Enum.map(& &1.args)
      assert_lists_equal(expected_apns_jobs, actual_apns_jobs)

      # verify apns executed

      expect(MockAPNS, :push, 2, fn
        %Notification{device_token: "BABABABABA"} = n, :dev ->
          assert n.payload == %{
                   "aps" => %{
                     "alert" => %{"title" => "Your session has expired"},
                     "badge" => 1,
                     "mutable-content" => 1
                   },
                   "type" => "session_expired"
                 }

          %Notification{n | response: :success}

        %Notification{device_token: "ABABABABAB"} = n, :dev ->
          assert n.payload == %{
                   "aps" => %{
                     "alert" => %{"title" => "Твоя сессия завершена"},
                     "badge" => 1,
                     "mutable-content" => 1
                   },
                   "type" => "session_expired"
                 }

          %Notification{n | response: :success}
      end)

      assert %{failure: 0, success: 2} = Oban.drain_queue(queue: :apns, with_safety: false)
    end
  end
end
