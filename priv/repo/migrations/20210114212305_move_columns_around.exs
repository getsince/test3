defmodule T.Repo.Migrations.MoveColumnsAround do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :deleted_at, :timestamptz
      # add :last_active,
    end
  end
end
