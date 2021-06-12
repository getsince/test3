defmodule T.Repo.Migrations.DropUserDeletedAt do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :deleted_at
    end
  end
end
