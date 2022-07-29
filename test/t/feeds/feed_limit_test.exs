defmodule T.Feeds.FeedLimitTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: T.Repo

  alias T.{Feeds, PushNotifications.DispatchJob}
  alias T.Feeds.{FeedLimit, FeedLimitResetJob}

  describe "insert_feed_limit/1" do
    test "creates feed limit and schedules a reset feed limit job in the future" do
      %{user_id: user_id} = feed_limit(timestamp: ~U[2021-01-01 12:00:00Z])

      assert [
               %Oban.Job{
                 args: %{"user_id" => ^user_id},
                 # in twelve hours
                 scheduled_at: ~U[2021-01-02 00:00:00.000000Z]
               }
             ] = all_enqueued(worker: FeedLimitResetJob)
    end
  end

  describe "feed_limits_prune/0,1" do
    test "feed_limit not reached reset side effects" do
      feed_limit_period_ago = DateTime.add(DateTime.utc_now(), -Feeds.feed_limit_period() - 1)
      feed_limit = feed_limit(timestamp: feed_limit_period_ago, reached: false)
      user_id = feed_limit.user_id

      Feeds.subscribe_for_user(user_id)

      parent = self()

      spawn(fn ->
        Feeds.subscribe_for_user(user_id)

        Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())

        # trigger scheduled FeedLimitResetJob
        assert %{success: 1} =
                 Oban.drain_queue(queue: :default, with_safety: false, with_scheduled: true)
      end)

      assert_receive {Feeds, :feed_limit_reset}

      refute FeedLimit |> where(user_id: ^user_id) |> Repo.exists?()

      assert Enum.map(all_enqueued(worker: DispatchJob), fn job -> job.args end) == []
    end

    test "feed_limit reached reset side effects" do
      feed_limit_period_ago = DateTime.add(DateTime.utc_now(), -Feeds.feed_limit_period() - 1)
      feed_limit = feed_limit(timestamp: feed_limit_period_ago, reached: true)
      user_id = feed_limit.user_id

      Feeds.subscribe_for_user(user_id)

      parent = self()

      spawn(fn ->
        Feeds.subscribe_for_user(user_id)

        Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())

        # trigger scheduled FeedLimitResetJob
        assert %{success: 1} =
                 Oban.drain_queue(queue: :default, with_safety: false, with_scheduled: true)
      end)

      assert_receive {Feeds, :feed_limit_reset}

      refute FeedLimit |> where(user_id: ^user_id) |> Repo.exists?()

      assert Enum.map(all_enqueued(worker: DispatchJob), fn job -> job.args end) == [
               %{"type" => "feed_limit_reset", "user_id" => user_id}
             ]
    end
  end

  defp feed_limit(opts) do
    %{user_id: user_id} = insert(:profile)
    timestamp = opts[:timestamp] || DateTime.utc_now()
    assert %FeedLimit{} = feed_limit = Feeds.insert_feed_limit(user_id, timestamp)

    if reached = opts[:reached] do
      {1, [feed_limit]} =
        FeedLimit
        |> where(user_id: ^user_id)
        |> select([f], f)
        |> Repo.update_all(set: [reached: reached])

      feed_limit
    else
      feed_limit
    end
  end
end
