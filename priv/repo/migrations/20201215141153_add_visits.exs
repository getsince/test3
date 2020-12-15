defmodule T.Repo.Migrations.AddVisits do
  use Ecto.Migration

  def change do
    create table(:visits, primary_key: false) do
      add :id, :uuid, null: false
      add :meta, :jsonb, default: "{}"
      timestamps(updated_at: false)
    end
  end
end
