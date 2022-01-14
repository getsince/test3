defmodule T.Periodics do
  @moduledoc "Supervisor for periodic tasks"
  use Supervisor
  alias T.{Accounts, Matches, Feeds}

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children =
      build_spec(
        seen_pruner: {
          _period = :timer.hours(1),
          _task = {Feeds, :prune_seen_profiles, [_ttl_days = 30]}
        },
        timeslots_pruner: {
          :timer.minutes(1),
          {Matches, :prune_stale_timeslots, []}
        },
        match_expirer: {
          :timer.minutes(1),
          fn ->
            Matches.expiration_notify_soon_to_expire()
            Matches.expiration_prune()
          end
        },
        scheduled_pushes: {
          :timer.minutes(1),
          {Accounts, :push_users_to_complete_onboarding, []}
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
