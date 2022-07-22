defmodule T.Workflows do
  @moduledoc "Basic workflow engine"
  use GenServer
  require Logger

  @task_sup T.TaskSupervisor
  @registry __MODULE__.Registry
  @supervisor __MODULE__.Supervisor

  @type uuid :: Ecto.Bigflake.UUID.t()
  @type changes :: %{atom => term}
  @type step ::
          {name :: atom,
           spec :: [up: (changes -> term), down: (changes -> term), attempts: pos_integer]}

  @type direction :: :up | :down

  @type state :: %{
          steps: [step],
          prev_steps: [step],
          changes: changes,
          direction: direction,
          attempt: pos_integer,
          task: Task.t() | nil
        }

  @type public_state :: %{
          steps: [atom],
          prev_steps: [atom],
          changes: %{atom => term},
          direction: direction,
          attempt: pos_integer
        }

  @pubsub T.PubSub

  defp topic, do: "workflows"
  # defp topic(workflow_id), do: "workflows:#{workflow_id}"
  def subscribe, do: Phoenix.PubSub.subscribe(@pubsub, topic())
  # def subscribe(workflow_id), do: Phoenix.PubSub.subscribe(@pubsub, topic(workflow_id))
  # def unsubscribe(workflow_id), do: Phoenix.PubSub.unsubscribe(@pubsub, topic(workflow_id))

  @doc false
  # def broadcast(workflow_id, event, data) do
  #   Phoenix.PubSub.broadcast(@pubsub, topic(workflow_id), {__MODULE__, event, data})
  # end

  def broadcast(event, data) do
    Phoenix.PubSub.broadcast(@pubsub, topic(), {__MODULE__, event, data})
  end

  @doc """
  Lists workflows running locally

      list_running()
      %{"00000182-4572-89e6-06e9-e8bbc6560000" => %{attempt: 1, changes: %{}, direction: :up, prev_steps: [], steps: [:a]}

  """
  @spec list_running :: %{uuid => public_state}
  def list_running do
    @registry
    |> Registry.select([{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.reduce(%{}, fn {id, pid}, acc ->
      case get_state(pid) do
        {:ok, state} -> Map.put(acc, id, state)
        {:error, :not_found} -> acc
      end
    end)
  end

  import T.Cluster, only: [list_primary_nodes: 0]

  @doc """
  Same as `list_running/0` but calls into primary nodes
  """
  @spec primary_list_running :: %{atom => [uuid]}
  def primary_list_running do
    Map.new(list_primary_nodes(), fn node ->
      {node, :erpc.call(node, __MODULE__, :list_running, [])}
    end)
  end

  @doc """
  Returns workflow pid if it's found locally

      whereis("00000182-4572-89e6-06e9-e8bbc6560000")
      #PID<0.688.0>

  """
  @spec whereis(uuid) :: pid | nil
  def whereis(workflow_id) do
    case Registry.lookup(@registry, workflow_id) do
      [] -> nil
      [{pid, _}] -> pid
    end
  end

  @doc """
  Same as `whereis/1` but calls into primary nodes
  """
  @spec primary_whereis(uuid) :: pid | nil
  def primary_whereis(workflow_id) do
    Enum.find_value(list_primary_nodes(), fn node ->
      :erpc.call(node, __MODULE__, :whereis, [workflow_id])
    end)
  end

  @doc """
  Returns workflow id if it's found locally

      pid_to_workflow_id(pid(0, 688, 0))
      "00000182-4572-89e6-06e9-e8bbc6560000"

  """
  @spec pid_to_workflow_id(pid) :: uuid | nil
  def pid_to_workflow_id(pid) do
    case Registry.keys(@registry, pid) do
      [workflow_id] -> workflow_id
      [] -> nil
    end
  end

  @doc """
  Example workflow:

      start_workflow(
        inputs: [
          up: fn _changes -> generate_inputs() end,
          down: fn %{inputs: inputs} -> cleanup_inputs(inputs) end,
        ],
        ec2: [
          up: fn _changes -> launch_ec2() end,
          down: fn %{ec2: ec2} -> terminate_ec2(ec2) end,
        ],
        ssh: [
          up: fn %{ec2: ec2} -> ssh_into(ec2) end,
          attempts: 10 # default is 5
        ],
        upload_inputs: [
          up: fn %{ssh: ssh, inputs: inputs} -> upload_inputs(ssh, inputs) end,
        ],
        run_script: [
          up: fn %{ssh: ssh} -> run_script(ssh) end
        ],
        output: [
          up: fn %{ssh: ssh} -> download_output(ssh) end,
          down: fn %{output: output} -> cleanup_output(output) end
        ],
        load_output: [
          up: fn %{output: output} -> load_output(output) end
        ]
      )

  """
  @spec start_workflow([step], GenServer.options()) :: DynamicSupervisor.on_start_child()
  def start_workflow(steps, opts \\ []) do
    workflow_id = Ecto.Bigflake.UUID.generate()
    opts = Keyword.put_new(opts, :name, via(workflow_id))
    child_spec = Supervisor.child_spec({__MODULE__, [steps | opts]}, restart: :transient)
    DynamicSupervisor.start_child(@supervisor, child_spec)
  end

  @doc """
  Forces workflow to clean up and stop.
  Currently executing task is terminated and current step is rolled back.
  """
  def shutdown_workflow(workflow_id) when is_binary(workflow_id) do
    GenServer.call(via(workflow_id), :shutdown)
  catch
    :exit, {:normal, _call} -> :ok
  end

  def shutdown_workflow(pid) when is_pid(pid) do
    GenServer.call(pid, :shutdown)
  catch
    :exit, {:normal, _call} -> :ok
  end

  @doc """
  Same as `shutdown_workflow/1` but calls into primary nodes
  """
  def primary_shutdown_workflow(workflow_id) do
    if pid = primary_whereis(workflow_id) do
      shutdown_workflow(pid)
    else
      {:error, :not_found}
    end
  end

  @spec get_state(uuid | pid) :: {:ok, public_state} | {:error, :not_found}
  def get_state(workflow_id) when is_binary(workflow_id) do
    GenServer.call(via(workflow_id), :get_state)
  catch
    :exit, {:noproc, _call} ->
      {:error, :not_found}
  end

  def get_state(pid) when is_pid(pid) do
    GenServer.call(pid, :get_state)
  catch
    :exit, {:noproc, _call} ->
      {:error, :not_found}
  end

  @doc false
  def start_link([steps | opts]) do
    GenServer.start_link(__MODULE__, steps, opts)
  end

  defp via(workflow_id) when is_binary(workflow_id) do
    {:via, Registry, {@registry, workflow_id}}
  end

  @spec new_state([step]) :: state
  defp new_state(steps) when is_list(steps) do
    %{
      steps: steps,
      prev_steps: [],
      changes: %{},
      attempt: 1,
      task: nil,
      direction: :up
    }
  end

  @impl true
  def init(steps) do
    {:ok, new_state(steps), {:continue, :init}}
  end

  @impl true
  def handle_continue(:init, state) do
    if new_state = next_step(state) do
      {:noreply, new_state}
    else
      {:stop, :normal, state}
    end
  end

  @spec next_step(state) :: state | nil
  defp next_step(%{direction: :up} = state) do
    %{
      steps: steps,
      prev_steps: prev_steps,
      changes: changes
    } = state

    case steps do
      [{_name, spec} = step | next_steps] ->
        if up = spec[:up] do
          broadcast(:up, self())
          %{state | task: async_nolink(up, changes)}
        else
          next_step(%{state | steps: next_steps, prev_steps: [step | prev_steps]})
        end

      [] = _no_next_steps ->
        next_step(%{state | direction: :down})
    end
  end

  defp next_step(%{direction: :down} = state) do
    %{prev_steps: prev_steps, changes: changes} = state

    case prev_steps do
      [{_name, spec} | prev_prev_steps] ->
        if down = spec[:down] do
          broadcast(:down, self())
          %{state | task: async_nolink(down, changes)}
        else
          next_step(%{state | prev_steps: prev_prev_steps})
        end

      [] = _no_prev_steps ->
        nil
    end
  end

  defp async_nolink(step, changes) when is_function(step, 1) do
    Task.Supervisor.async_nolink(@task_sup, fn -> step.(changes) end)
  end

  defp async_nolink({m, f, a}, changes) do
    Task.Supervisor.async_nolink(@task_sup, m, f, [changes | a])
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    %{
      steps: steps,
      prev_steps: prev_steps,
      changes: changes,
      direction: direction,
      attempt: attempt
    } = state

    reply = %{
      steps: Enum.map(steps, fn {name, _spec} -> name end),
      prev_steps: Enum.map(prev_steps, fn {name, _spec} -> name end),
      changes: changes,
      direction: direction,
      attempt: attempt
    }

    {:reply, {:ok, reply}, state}
  end

  def handle_call(:shutdown, _from, %{direction: :down} = state) do
    {:reply, :ok, state}
  end

  def handle_call(:shutdown, _from, %{direction: :up} = state) do
    %{task: task, steps: [current | next_steps], prev_steps: prev_steps} = state

    state = %{
      state
      | direction: :down,
        attempt: 1,
        steps: next_steps,
        prev_steps: [current | prev_steps]
    }

    new_state =
      case Task.Supervisor.terminate_child(@task_sup, task.pid) do
        :ok -> state
        {:error, :not_found} -> next_step(state)
      end

    if new_state do
      {:reply, :ok, new_state}
    else
      {:stop, :normal, state}
    end
  end

  @impl true
  def handle_info({ref, result}, %{direction: direction} = state) do
    Process.demonitor(ref, [:flush])

    state =
      case direction do
        :up ->
          %{
            steps: [{name, _spec} = finished | next_steps],
            prev_steps: prev_steps,
            changes: changes
          } = state

          %{
            state
            | steps: next_steps,
              attempt: 1,
              prev_steps: [finished | prev_steps],
              changes: Map.put(changes, name, result)
          }

        :down ->
          %{prev_steps: [_finished | prev_steps]} = state
          %{state | prev_steps: prev_steps, attempt: 1}
      end

    if new_state = next_step(state) do
      {:noreply, new_state}
    else
      {:stop, :normal, state}
    end
  end

  # TODO
  def handle_info({:DOWN, _ref, :process, _, _reason}, %{direction: direction} = state) do
    new_state =
      case direction do
        :up ->
          %{attempt: attempt, steps: [{name, spec} | _rest]} = state
          max_attempts = spec[:attempts] || 5

          if attempt < max_attempts do
            next_step(%{state | attempt: attempt + 1})
          else
            Logger.error(
              "Workflow #{inspect(self())} step #{name}:up failed more than #{max_attempts} times, rolling back"
            )

            next_step(%{state | direction: :down, attempt: 1})
          end

        :down ->
          %{attempt: attempt, prev_steps: [{name, spec} | prev_steps]} = state
          max_attempts = spec[:attempts] || 5

          if attempt < max_attempts do
            next_step(%{state | attempt: attempt + 1})
          else
            Logger.error(
              "Workflow #{inspect(self())} step #{name}:down failed more than #{max_attempts} times, skipping"
            )

            next_step(%{state | prev_steps: prev_steps, attempt: 1})
          end
      end

    if new_state do
      {:noreply, new_state}
    else
      {:stop, :normal, state}
    end
  end

  # TODO or outside monitoring? trap exits?
  # @impl true
  # def terminate(_reason, %{step: 0} = state) do
  #   state
  # end
end
