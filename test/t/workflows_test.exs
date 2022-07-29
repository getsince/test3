defmodule T.WorkflowsTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  alias T.Workflows

  describe "start_workflow/1" do
    test "goes up and down" do
      me = self()

      steps = [
        a: [
          up: fn changes ->
            send(me, {:a, :up, changes})
            :result_a
          end,
          down: fn changes -> send(me, {:a, :down, changes}) end
        ],
        b: [
          up: fn changes ->
            send(me, {:b, :up, changes})
            :result_b
          end,
          down: fn changes -> send(me, {:b, :down, changes}) end
        ],
        c: [
          up: fn changes ->
            send(me, {:c, :up, changes})
            :result_c
          end,
          down: fn changes -> send(me, {:c, :down, changes}) end
        ]
      ]

      {:ok, pid} = Workflows.start_workflow(steps)
      ref = Process.monitor(pid)

      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
      refute Process.alive?(pid)

      assert flush() == [
               {:a, :up, %{}},
               {:b, :up, %{a: :result_a}},
               {:c, :up, %{a: :result_a, b: :result_b}},
               {:c, :down, %{a: :result_a, b: :result_b, c: :result_c}},
               {:b, :down, %{a: :result_a, b: :result_b, c: :result_c}},
               {:a, :down, %{a: :result_a, b: :result_b, c: :result_c}}
             ]
    end

    test "without cleanup goes only up" do
      me = self()

      steps = [
        a: [
          up: fn changes ->
            send(me, {:a, :up, changes})
            :ok
          end
        ],
        b: [
          up: fn changes ->
            send(me, {:b, :up, changes})
            :ok
          end
        ],
        c: [
          up: fn changes ->
            send(me, {:c, :up, changes})
            :ok
          end
        ]
      ]

      {:ok, pid} = Workflows.start_workflow(steps)
      ref = Process.monitor(pid)

      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
      refute Process.alive?(pid)

      assert flush() == [
               {:a, :up, %{}},
               {:b, :up, %{a: :ok}},
               {:c, :up, %{a: :ok, b: :ok}}
             ]
    end

    test "retries failures up to max_attempts then cleans up" do
      me = self()

      steps = [
        a: [
          up: fn changes ->
            send(me, {:a, :up, changes})
            :ok
          end,
          down: fn changes ->
            send(me, {:a, :down, changes})
          end
        ],
        b: [
          up: fn changes ->
            send(me, {:b, :up, changes})
            raise "oops"
          end,
          down: fn changes ->
            send(me, {:b, :down, changes})
          end
        ],
        c: [
          up: fn changes ->
            send(me, {:c, :up, changes})
            :ok
          end,
          down: fn changes ->
            send(me, {:c, :down, changes})
          end
        ]
      ]

      log =
        capture_log(fn ->
          {:ok, pid} = Workflows.start_workflow(steps)
          send(me, {:pid, pid})
          ref = Process.monitor(pid)

          assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
          refute Process.alive?(pid)
        end)

      assert_receive {:pid, pid}

      assert log =~
               "[error] Workflow #{inspect(pid)} step b:up failed more than 5 times, rolling back"

      assert flush() == [
               {:a, :up, %{}},
               {:b, :up, %{a: :ok}},
               {:b, :up, %{a: :ok}},
               {:b, :up, %{a: :ok}},
               {:b, :up, %{a: :ok}},
               {:b, :up, %{a: :ok}},
               {:a, :down, %{a: :ok}}
             ]
    end
  end

  test "discovery" do
    me = self()

    {:ok, pid} =
      Workflows.start_workflow(
        wait: [
          up: fn _changes ->
            send(me, {:waiter, self()})

            receive do
              :finish -> :ok
            end
          end
        ]
      )

    workflow_id = Workflows.pid_to_workflow_id(pid)
    assert Workflows.whereis(workflow_id) == pid

    assert Workflows.list_running() == %{
             workflow_id => %{
               attempt: 1,
               changes: %{},
               direction: :up,
               prev_steps: [],
               steps: [:wait]
             }
           }

    assert {:ok,
            %{
              attempt: 1,
              changes: %{},
              direction: :up,
              prev_steps: [],
              steps: [:wait]
            }} == Workflows.get_state(pid)

    assert {:ok,
            %{
              attempt: 1,
              changes: %{},
              direction: :up,
              prev_steps: [],
              steps: [:wait]
            }} == Workflows.get_state(workflow_id)

    assert Process.alive?(pid)
    ref = Process.monitor(pid)

    assert_receive {:waiter, waiter}
    send(waiter, :finish)

    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
    refute Process.alive?(pid)
  end

  describe "shutdown_workflow" do
    test "by pid" do
      me = self()

      {:ok, pid} =
        Workflows.start_workflow(
          a: [
            up: fn changes ->
              send(me, {:a, :up, changes})
              :result_a
            end,
            down: fn changes ->
              send(me, {:a, :down, changes})
            end
          ],
          b: [
            up: fn changes ->
              send(me, {:b, :up, changes})
              send(me, {:waiter, self()})

              receive do
                :finish -> :ok
              end
            end,
            down: fn changes ->
              send(me, {:b, :down, changes})
            end
          ],
          c: [
            up: fn changes ->
              send(me, {:c, :up, changes})
            end
          ]
        )

      ref = Process.monitor(pid)
      workflow_id = Workflows.pid_to_workflow_id(pid)

      assert_receive {:waiter, waiter}

      assert {:ok,
              %{
                attempt: 1,
                changes: %{a: :result_a},
                direction: :up,
                prev_steps: [:a],
                steps: [:b, :c]
              }} == Workflows.get_state(pid)

      assert :ok = Workflows.shutdown_workflow(workflow_id)
      refute Process.alive?(waiter)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
      refute Process.alive?(pid)

      assert flush() == [
               {:a, :up, %{}},
               {:b, :up, %{a: :result_a}},
               {:b, :down, %{a: :result_a}},
               {:a, :down, %{a: :result_a}}
             ]
    end

    test "with failing `down`" do
      me = self()

      {:ok, pid} =
        Workflows.start_workflow(
          a: [
            up: fn changes ->
              send(me, {:a, :up, changes})
              :result_a
            end,
            down: fn changes ->
              send(me, {:a, :down, changes})
            end
          ],
          b: [
            up: fn changes ->
              send(me, {:b, :up, changes})
              send(me, {:waiter, self()})

              receive do
                :finish -> :ok
              end
            end,
            down: fn %{b: :ok} = changes ->
              send(me, {:b, :down, changes})
            end
          ],
          c: [
            up: fn changes ->
              send(me, {:c, :up, changes})
            end
          ]
        )

      ref = Process.monitor(pid)
      workflow_id = Workflows.pid_to_workflow_id(pid)

      assert_receive {:waiter, waiter}

      assert {:ok,
              %{
                attempt: 1,
                changes: %{a: :result_a},
                direction: :up,
                prev_steps: [:a],
                steps: [:b, :c]
              }} == Workflows.get_state(pid)

      capture_log(fn ->
        assert :ok = Workflows.shutdown_workflow(workflow_id)
        refute Process.alive?(waiter)
        assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
        refute Process.alive?(pid)
      end)

      assert flush() == [
               {:a, :up, %{}},
               {:b, :up, %{a: :result_a}},
               {:a, :down, %{a: :result_a}}
             ]
    end
  end

  defp flush do
    receive do
      message -> [message | flush()]
    after
      0 -> []
    end
  end
end
