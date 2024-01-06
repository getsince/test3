defmodule T.Cluster do
  @moduledoc false
  require Logger

  @spec poll_digitalocean(String.t(), String.t()) :: [ip_address :: String.t()]
  def poll_digitalocean(tag, token) do
    url =
      "https://api.digitalocean.com/v2/droplets?" <>
        URI.encode_query([{"tag_name", tag}, {"status", "active"}])

    headers = [{"accept", "application/json"}, {"authorization", "Bearer " <> token}]

    req = Finch.build(:get, url, headers)

    case Finch.request!(req, T.Finch) do
      %Finch.Response{status: 200, body: body} ->
        Jason.decode!(body)
        |> Map.fetch!("droplets")
        |> Enum.map(fn droplet ->
          %{"networks" => %{"v4" => v4}} = droplet
          [%{"ip_address" => ip_address}] = Enum.filter(v4, &(&1["type"] == "private"))
          ip_address
        end)

      respone ->
        Logger.error("unexpected response in T.Cluster.poll_digitalocean: #{inspect(response)}")
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
    Enum.filter([node() | Node.list()], fn node -> is_primary(node, primary_prefix) end)
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
