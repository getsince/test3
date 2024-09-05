defmodule Since.Games.ComplimentLimitTest do
  use Since.DataCase, async: true
  use Oban.Testing, repo: Since.Repo

  alias Since.{Games, PushNotifications.DispatchJob}
  alias Since.Games.{ComplimentLimit, ComplimentLimitResetJob}

  describe "insert_compliment_limit/1" do
    test "creates compliment limit and schedules a reset compliment limit job in the future" do
      %{user_id: user_id} = compliment_limit(timestamp: ~U[2021-01-01 12:00:00Z])

      assert [
               %Oban.Job{
                 args: %{"user_id" => ^user_id},
                 # in twelve hours
                 scheduled_at: ~U[2021-01-02 00:00:00.000000Z]
               }
             ] = all_enqueued(worker: ComplimentLimitResetJob)
    end
  end

  describe "compliment_limits_prune/0,1" do
    test "compliment_limit not reached reset side effects" do
      compliment_limit_period_ago =
        DateTime.add(DateTime.utc_now(), -Games.compliment_limit_period() - 1)

      compliment_limit = compliment_limit(timestamp: compliment_limit_period_ago, reached: false)
      user_id = compliment_limit.user_id

      # trigger scheduled FeedLimitResetJob
      assert %{success: 1} =
               Oban.drain_queue(queue: :default, with_safety: false, with_scheduled: true)

      refute ComplimentLimit |> where(user_id: ^user_id) |> Since.Repo.exists?()

      assert Enum.map(all_enqueued(worker: DispatchJob), fn job -> job.args end) == []
    end

    test "compliment_limit reached reset side effects" do
      compliment_limit_period_ago =
        DateTime.add(DateTime.utc_now(), -Games.compliment_limit_period() - 1)

      compliment_limit = compliment_limit(timestamp: compliment_limit_period_ago, reached: true)
      user_id = compliment_limit.user_id

      # trigger scheduled FeedLimitResetJob
      assert %{success: 1} =
               Oban.drain_queue(queue: :default, with_safety: false, with_scheduled: true)

      refute ComplimentLimit |> where(user_id: ^user_id) |> Since.Repo.exists?()

      assert Enum.map(all_enqueued(worker: DispatchJob), fn job -> job.args end) == [
               %{"type" => "compliment_limit_reset", "prompt" => "like", "user_id" => user_id}
             ]
    end
  end

  defp compliment_limit(opts) do
    %{user_id: user_id} = insert(:profile)
    timestamp = opts[:timestamp] || DateTime.utc_now()

    assert {:ok, %{limit: %ComplimentLimit{} = compliment_limit, reset: %Oban.Job{}}} =
             Games.insert_compliment_limit(user_id, "like", timestamp)

    if reached = opts[:reached] do
      {1, [compliment_limit]} =
        ComplimentLimit
        |> where(user_id: ^user_id)
        |> select([l], l)
        |> Repo.update_all(set: [reached: reached])

      compliment_limit
    else
      compliment_limit
    end
  end
end
