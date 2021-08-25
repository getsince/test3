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

      {:error, reason} ->
        Logger.error(
          "failed to fetch location for #{inspect(ip_address)}, reason: #{inspect(reason)}"
        )

        nil
    end
  end
end
