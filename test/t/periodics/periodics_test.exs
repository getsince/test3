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
    assert_in_delta passed_1, 50, 10

    # the second task runs ~50ms after the first
    assert_in_delta passed_2 - passed_1, 50, 10
  end

  test "T.Periodics starts all tasks which don't crash when run" do
    start_supervised!(T.Periodics)
    children = Supervisor.which_children(T.Periodics)
    me = self()

    assert [
             {:feed_limit_pruner, _, :worker, [Periodic]},
             {:match_expirer, _, :worker, [Periodic]},
             {:seen_pruner, _, :worker, [Periodic]}
           ] = children

    # smoke test that nothing crashes during run
    Enum.each(children, fn {_id, pid, :worker, [Periodic]} ->
      Ecto.Adapters.SQL.Sandbox.allow(Repo, me, pid)
      send(pid, :run)
      assert {_period, _fun} = :sys.get_state(pid)
    end)
  end
end
