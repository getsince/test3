defmodule Since.Geo do
  @moduledoc "Helpers for working with geographic data."
  import Ecto.Query

  @spec point_to_h3(Geo.Point.t()) :: :h3.h3_index()
  def point_to_h3(point) do
    %Geo.Point{coordinates: {lon, lat}, srid: 4326} = point
    :h3.from_geo({lat / 1, lon / 1}, 7)
  end

  @doc """
  Computes [approximated](https://jonisalonen.com/2014/computing-distance-between-coordinates-can-be-simple-and-fast/)
  distance in kilometers between two H3 indexes.
  """
  defmacro fast_distance_km(target_h3, origin_h3) do
    quote do
      fragment("fast_distance_km(?,?)", unquote(target_h3), unquote(origin_h3))
    end
  end
end
