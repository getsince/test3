defmodule T.Periodics do
  @moduledoc "Supervisor for periodic tasks"
  use Supervisor
  alias T.{Matches, Feeds}

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
        timeslots_pruner: {
          :timer.minutes(1),
          {Matches, :local_prune_stale_timeslots, []}
        },
        match_expirer: {
          :timer.minutes(1),
          {Matches, :expiration_prune, []}
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
