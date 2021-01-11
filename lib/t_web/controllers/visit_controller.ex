defmodule TWeb.VisitController do
  use TWeb, :controller

  action_fallback TWeb.FallbackController

  def create(conn, attrs) do
    attrs = Map.put(attrs, "meta", ControllerHelpers.build_meta(conn, attrs))

    with {:ok, _visit} <- T.Visits.save_visit(attrs) do
      send_resp(conn, 201, [])
    end
  end
end
