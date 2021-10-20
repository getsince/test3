defmodule T.Cluster do
  @moduledoc false

  @spec resolve_route53_srv(String.t()) :: [:inet.ip_address()]
  def resolve_route53_srv(query) do
    String.to_charlist(query)
    |> :inet_res.lookup(:in, :srv)
    |> Enum.map(fn {_, _, _, a} -> :inet_res.lookup(a, :in, :a) end)
    |> List.flatten()
  end
end
