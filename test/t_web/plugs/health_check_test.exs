defmodule TWeb.Plugs.HealthCheckTest do
  use TWeb.ConnCase, async: true

  test "success: returns 200 when healthy", %{conn: conn} do
    conn = get(conn, "/health")

    assert conn.status == 200
    assert conn.resp_body == ""
  end
end
