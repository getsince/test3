defmodule T.Twilio.Adapter do
  @moduledoc false
  @callback fetch_ice_servers() :: [map]
end
