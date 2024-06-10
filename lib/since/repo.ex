defmodule Since.Repo do
  use Ecto.Repo,
    otp_app: :since,
    adapter: Ecto.Adapters.SQLite3
end
