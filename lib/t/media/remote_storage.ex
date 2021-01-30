defmodule T.Media.RemoteStorage do
  @moduledoc false
  @callback file_exists?(key :: String.t()) :: boolean
end
