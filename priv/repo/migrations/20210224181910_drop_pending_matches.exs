defmodule T.Repo.Migrations.DropPendingMatches do
  use Ecto.Migration

  def up do
    alter table(:matches) do
      remove :pending?
    end
  end
end
