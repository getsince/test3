defmodule T.Cluster do
  @moduledoc false

  # 10.0.0.0/16 -> eu-north-1 (primary)
  # 10.1.0.0/16 -> us-east-2 (replica)

  @spec poll_ec2(String.t(), [String.t()]) :: [ip_address :: String.t()]
  def poll_ec2(name, regions) do
    # maybe use vpc-id per region as well?

    request =
      ExAws.EC2.describe_instances(
        filters: [
          {"tag:Name", name},
          {"instance-state-name", "running"}
        ]
      )

    xpath = private_ip_address_xpath()

    regions
    |> Enum.map(fn region ->
      {:ok, %{body: body}} = ExAws.request(request, region: region)
      body |> SweetXml.xpath(xpath) |> Enum.uniq()
    end)
    |> List.flatten()
  end

  defp private_ip_address_xpath do
    import SweetXml, only: [sigil_x: 2]

    ~x"//DescribeInstancesResponse/reservationSet/item/instancesSet/item/privateIpAddress/text()"ls
  end

  @doc """
  Checks if the node is in primary region.

      iex> is_primary() # checks self
      false

      iex> is_primary(:"t@10.0.1.234")
      true

      iex> is_primary(:"t@10.1.0.88")
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

      iex> primary_prefix()
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
