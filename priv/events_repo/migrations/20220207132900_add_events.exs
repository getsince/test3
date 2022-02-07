defmodule T.Events.Repo.Migrations.AddEvents do
  use Ecto.Migration

  def up do
    execute """
    CREATE TABLE "events" (
      "id" BLOB NOT NULL PRIMARY KEY,
      "name" TEXT NOT NULL,
      "actor" BLOB,
      "data" JSON
    ) WITHOUT ROWID
    """
  end

  def down do
    drop table(:events)
  end
end
