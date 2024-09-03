defmodule SinceWeb.LocationController do
  use SinceWeb, :controller

  def get(conn, _params) do
    [_lat, _lon] = location = Since.Location.location_from_ip(conn.remote_ip)
    json(conn, %{location: location})
  end
end
