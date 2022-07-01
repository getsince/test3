defmodule T.Feeds.FeedLimitTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: T.Repo

  alias T.{Feeds, PushNotifications.DispatchJob}
  alias T.Feeds.{FeedLimit}

  describe "list_reset_feed_limits/0,1" do
    test "doesn't list recent feed_limits" do
      feed_limit(timestamp: ~N[2021-01-01 12:00:00])
      assert Feeds.list_reset_feed_limits(_at = ~U[2021-01-01 12:00:01Z]) == []
    end

    test "lists old feed_limits" do
      feed_limit = feed_limit(timestamp: ~N[2021-01-01 12:00:00])
      assert Feeds.list_reset_feed_limits(_at = ~U[2021-01-04 12:00:00Z]) == [feed_limit]
    end
  end

  describe "feed_limits_prune/0,1" do
    test "feed_limit not reached reset side effects" do
      feed_limit = feed_limit(timestamp: ~N[2021-01-01 12:00:00], reached: false)
      user_id = feed_limit.user_id

      Feeds.subscribe_for_user(user_id)

      parent = self()

      spawn(fn ->
        Feeds.subscribe_for_user(user_id)

        Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())
        assert :ok = Feeds.feed_limits_prune(~U[2021-01-04 12:00:00Z])
      end)

      assert_receive {Feeds, :feed_limit_reset}

      refute FeedLimit |> where(user_id: ^user_id) |> T.Repo.exists?()

      assert Enum.map(all_enqueued(worker: DispatchJob), fn job -> job.args end) == []
    end

    test "feed_limit reached reset side effects" do
      feed_limit = feed_limit(timestamp: ~N[2021-01-01 12:00:00], reached: true)
      user_id = feed_limit.user_id

      Feeds.subscribe_for_user(user_id)

      parent = self()

      spawn(fn ->
        Feeds.subscribe_for_user(user_id)

        Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())
        assert :ok = Feeds.feed_limits_prune(~U[2021-01-04 12:00:00Z])
      end)

      assert_receive {Feeds, :feed_limit_reset}

      refute FeedLimit |> where(user_id: ^user_id) |> T.Repo.exists?()

      assert Enum.map(all_enqueued(worker: DispatchJob), fn job -> job.args end) == [
               %{"type" => "feed_limit_reset", "user_id" => user_id}
             ]
    end
  end

  defp feed_limit(opts) do
    me = insert(:profile)

    insert(:feed_limit,
      user_id: me.user_id,
      timestamp: opts[:timestamp],
      reached: opts[:reached] || false
    )
  end
end
