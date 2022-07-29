defmodule T.Periodics do
  @moduledoc "Supervisor for periodic tasks"
  use Supervisor
  alias T.{Matches, Feeds, FeedAI}

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children =
      build_spec(
        seen_pruner: {
          _period = :timer.hours(1),
          _task = {Feeds, :local_prune_seen_profiles, [_ttl_days = 30]}
        },
        match_expirer: {
          :timer.minutes(1),
          {Matches, :expiration_prune, []}
        },
        feed_limit_pruner: {
          :timer.seconds(1),
          {Feeds, :feed_limits_prune, []}
        },
        feed_ai: {
          :timer.hours(2),
          {FeedAI, :start_workflow, []}
        },
        prune_feed_ai_ec2: {
          :timer.minutes(10),
          {FeedAI, :prune_stray_instances, []}
        }
      )

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp build_spec(tasks) do
    Enum.map(tasks, fn {id, state} ->
      Supervisor.child_spec({Periodic, state}, id: id)
    end)
  end
end
