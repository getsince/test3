defmodule T.PeriodicsTest do
  use T.DataCase, async: true

  test "task is executed after every period" do
    me = self()
    start = DateTime.utc_now()

    start_supervised!(
      {Periodic,
       {_period_ms = 50,
        fn ->
          passed = DateTime.diff(DateTime.utc_now(), start, :millisecond)
          send(me, passed)
        end}}
    )

    assert_receive passed_1
    refute_received _anything_else

    assert_receive passed_2
    refute_received _anything_else

    # the first task runs after ~50ms
    assert_in_delta passed_1, 50, 30

    # the second task runs ~50ms after the first
    assert_in_delta passed_2 - passed_1, 50, 10
  end

  test "T.Periodics starts all tasks which don't crash when run" do
    start_supervised!(T.Periodics)
    children = Supervisor.which_children(T.Periodics)
    me = self()

    assert [
             {:prune_feed_ai_ec2, _, :worker, [Periodic]},
             {:feed_ai, _, :worker, [Periodic]},
             {:seen_pruner, _, :worker, [Periodic]}
           ] = children

    # smoke test that nothing crashes during run
    Enum.each(children, fn {id, pid, :worker, [Periodic]} ->
      # except for feed ai since it touches aws resources
      unless id in [:feed_ai, :prune_feed_ai_ec2] do
        Ecto.Adapters.SQL.Sandbox.allow(Repo, me, pid)
        send(pid, :run)
        assert {_period, _fun} = :sys.get_state(pid)
      end
    end)
  end
end
