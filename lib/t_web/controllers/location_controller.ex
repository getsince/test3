defmodule TWeb.LocationController do
  use TWeb, :controller

  def get(conn, _params) do
    [_lat, _lon] = location = T.Location.location_from_ip(conn.remote_ip)
    json(conn, %{location: location})
  end
end
