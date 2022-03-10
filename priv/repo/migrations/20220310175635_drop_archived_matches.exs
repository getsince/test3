defmodule T.Repo.Migrations.DropArchivedMatches do
  use Ecto.Migration

  def change do
    drop table(:archived_matches)
  end
end
