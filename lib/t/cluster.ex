defmodule T.Cluster do
  @moduledoc false

  # 10.0.0.0/16 -> eu-north-1 (primary)
  # 10.1.0.0/16 -> us-east-2 (replica)
  # 10.2.0.0/16 -> us-west-1 (replica)
  # 10.3.0.0/16 -> ap-southeast-2 (replica)
  # 10.4.0.0/16 -> sa-east-1 (replica)

  @spec poll_ec2(String.t(), [String.t()]) :: [ip_address :: String.t()]
  def poll_ec2(name, regions) do
    client = T.aws_client()

    T.async_stream(
      regions,
      fn region ->
        client = %AWS.Client{client | region: region}
        list_private_ips(client, name)
      end,
      ordered: false
    )
    |> Enum.reduce([], fn
      {:ok, ips}, acc -> ips ++ acc
      _other, acc -> acc
    end)
  end

  # TODO maybe list ips (network intfaces), need to tag them
  defp list_private_ips(client, name) do
    # TODO retry?
    {:ok, %{"DescribeInstancesResponse" => %{"reservationSet" => reservation_set}}, _resp} =
      AWS.EC2.describe_instances(client, %{
        "Filter.1.Name" => "tag:Name",
        "Filter.1.Value.1" => name,
        "Filter.2.Name" => "instance-state-name",
        "Filter.2.Value.1" => "running"
      })

    case reservation_set do
      %{"item" => instances} ->
        if is_list(instances) do
          get_in(instances, [Access.all(), "instancesSet", "item", "privateIpAddress"])
        else
          [get_in(instances, ["instancesSet", "item", "privateIpAddress"])]
        end

      :none ->
        []
    end
  end

  @doc """
  Checks if the node is in primary region.

      is_primary() # checks self
      true

      is_primary(:"t@10.0.1.234")
      true

      is_primary(:"t@10.1.0.88")
      false

      iex> is_primary(:"t@10.1.0.88", "10.1.")
      true

  """
  @spec is_primary(node, String.t()) :: boolean
  def is_primary(node \\ node(), primary_prefix \\ primary_prefix()) do
    [_name, host] = node |> to_string() |> String.split("@")
    String.starts_with?(host, primary_prefix)
  end

  @doc """
  Returns host prefix for nodes in primary region.

      primary_prefix()
      "10.0."

  """
  @spec primary_prefix :: String.t()
  def primary_prefix do
    # TODO use cidr
    Application.fetch_env!(:t, :primary_prefix)
  end

  @doc """
  Lists known node in primary region.

      list_primary_nodes()
      [:"t@10.0.1.234", :"t@10.0.2.73"]

  """
  @spec list_primary_nodes :: [node]
  def list_primary_nodes do
    primary_prefix = primary_prefix()
    Enum.filter(Node.list(), fn node -> is_primary(node, primary_prefix) end)
  end

  @doc """
  Returns a random node in primary region if available.

      random_primary_node()
      :"t@10.0.1.234"

      random_primary_node()
      nil

  """
  @spec random_primary_node :: node | nil
  def random_primary_node do
    case list_primary_nodes() do
      [] -> nil
      nodes -> Enum.random(nodes)
    end
  end

  @doc """
  Runs the given MFA on a random node in primary region.

      primary_rpc(Kernel, :+, [1, 2])
      3

      params = %{name: "John", email: "john@example.com"}
      primary_rpc(T.Accounts, :local_create_user, [params])
      {:ok, %T.Accounts.User{name: "John", email: "john@example.com"}}

  """
  @spec primary_rpc(node, atom, [term]) :: term
  def primary_rpc(m, f, a) do
    if is_primary() do
      apply(m, f, a)
    else
      :erpc.call(random_primary_node(), m, f, a)
    end
  end
end
