defmodule T.Location do
  require Logger

  @db :city

  def setup(key) do
    :ok = Application.put_env(:locus, :license_key, key)
    :ok = :locus.start_loader(@db, {:maxmind, "GeoLite2-City"})
  end

  def location_from_ip(ip_address) do
    case :locus.lookup(@db, ip_address) do
      {:ok, %{"location" => %{"latitude" => lat, "longitude" => lon}}} ->
        [lat, lon]

      {:error, :database_unknown} ->
        Logger.error("location database_unknown}")
        [55.755516, 37.615040]

      :not_found ->
        Logger.error("couldn't find location for ip address #{inspect(ip_address)}")
        nil
    end
  end
end
