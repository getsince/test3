defmodule TWeb.VisitController do
  use TWeb, :controller

  action_fallback TWeb.FallbackController

  def create(conn, attrs) do
    meta =
      (attrs["meta"] || %{})
      |> Map.put("ip", conn.remote_ip |> :inet.ntoa() |> to_string())
      |> Map.put("user-agent", conn |> get_req_header("user-agent") |> List.first())

    attrs = Map.put(attrs, "meta", meta)

    with {:ok, _visit} <- T.Visits.save_visit(attrs) do
      send_resp(conn, 201, [])
    end
  end
end
