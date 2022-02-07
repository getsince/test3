defmodule T.Events.Repo do
  use Ecto.Repo, otp_app: :t, adapter: Ecto.Adapters.SQLite3
end
