defmodule Since.Repo.Migrations.AddPgH3 do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS h3",
            "DROP EXTENSION IF EXISTS h3"
  end
end
