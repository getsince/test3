defmodule TWeb.ControllerHelpers do
  import Plug.Conn

  def build_meta(conn, attrs) do
    (attrs["meta"] || %{})
    |> Map.put("ip", conn.remote_ip |> :inet.ntoa() |> to_string())
    |> Map.put("user-agent", conn |> get_req_header("user-agent") |> List.first())
    |> maybe_put("code", attrs["code"])
    |> maybe_put("ref", attrs["ref"])
    |> maybe_put("click_id", attrs["click_id"])
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
