# based on https://github.com/kyleaa/libcluster_ec2/blob/master/lib/strategy/tags.ex
defmodule T.Cluster.Strategy do
  @moduledoc """
  Polls for private ipv4 addresses on ec2 instances in multiple regions filtering by tag:Name.

  Example configuration:

      config :libcluster,
        topologies: [
          aws: [
            strategy: #{__MODULE__},
            config: [
              app_prefix: :e,
              name: "since",
              polling_interval: :timer.seconds(5),
              regions: ["eu-north-1", "us-east-2"]
            ]
          ]
        ]

  """

  use GenServer
  use Cluster.Strategy
  alias Cluster.Strategy.State

  @default_polling_interval 5_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl GenServer
  def init([%State{} = state]) do
    state = %State{state | meta: MapSet.new()}
    {:ok, load(state)}
  end

  @impl GenServer
  def handle_info(:timeout, state) do
    handle_info(:load, state)
  end

  def handle_info(:load, state) do
    {:noreply, load(state)}
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  @spec load(State.t()) :: State.t()
  defp load(state) do
    %State{topology: topology, connect: connect, disconnect: disconnect, list_nodes: list_nodes} =
      state

    new_nodelist = get_nodes_set(state)
    removed = state.meta |> MapSet.difference(new_nodelist) |> MapSet.to_list()
    added = new_nodelist |> MapSet.difference(state.meta) |> MapSet.to_list()

    new_nodelist =
      case Cluster.Strategy.disconnect_nodes(topology, disconnect, list_nodes, removed) do
        :ok ->
          new_nodelist

        {:error, bad_nodes} ->
          # Add back the nodes which should have been removed, but which couldn't be for some reason
          Enum.reduce(bad_nodes, new_nodelist, fn {n, _}, acc ->
            MapSet.put(acc, n)
          end)
      end

    new_nodelist =
      case Cluster.Strategy.connect_nodes(topology, connect, list_nodes, added) do
        :ok ->
          new_nodelist

        {:error, bad_nodes} ->
          # Remove the nodes which should have been added, but couldn't be for some reason
          Enum.reduce(bad_nodes, new_nodelist, fn {n, _}, acc ->
            MapSet.delete(acc, n)
          end)
      end

    schedule_next_load(state)
    %State{state | meta: new_nodelist}
  end

  defp schedule_next_load(state) do
    time = state.config[:polling_interval] || @default_polling_interval
    Process.send_after(self(), :load, time)
  end

  @spec get_nodes_set(State.t()) :: MapSet.t(atom)
  defp get_nodes_set(%State{config: config}) do
    regions = Keyword.fetch!(config, :regions)
    name = Keyword.fetch!(config, :name)
    app_prefix = Keyword.fetch!(config, :app_prefix)

    T.Cluster.poll_ec2(name, regions)
    |> Enum.map(fn ip -> :"#{app_prefix}@#{ip}" end)
    |> MapSet.new()
  end
end
