defmodule Since.Geo do
  @moduledoc "Helpers for working with geographic data."
  import Ecto.Query, warn: false

  @spec point_to_h3(Geo.Point.t()) :: non_neg_integer
  def point_to_h3(point) do
    %Geo.Point{coordinates: {lon, lat}, srid: 4326} = point
    :h3.from_geo({lat / 1, lon / 1}, 7)
  end

  defmacro h3_great_circle_distance_km(origin, target) do
    quote do
      fragment(
        "round(h3_great_circle_distance(h3_cell_to_lat_lng(?::bigint::h3index),h3_cell_to_lat_lng(?::bigint::h3index)))::int",
        unquote(origin),
        unquote(target)
      )
    end
  end

  # TODO safe?
  defmacro h3_grid_distance(origin, target) do
    quote do
      fragment(
        "h3_grid_distance(?::bigint::h3index, ?::bigint::h3index)",
        unquote(origin),
        unquote(target)
      )
    end
  end
end
