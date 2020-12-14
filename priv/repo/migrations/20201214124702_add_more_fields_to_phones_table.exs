defmodule T.Repo.Migrations.AddMoreFieldsToPhonesTable do
  use Ecto.Migration

  def change do
    execute "TRUNCATE phones;"
    alter table(:phones) do
      add :meta, :jsonb, default: "{}"
      timestamps(updated_at: false)
    end
  end
end
