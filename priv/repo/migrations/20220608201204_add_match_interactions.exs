defmodule Since.Repo.Migrations.AddMatchInterations do
  use Ecto.Migration

  def change do
    create table(:match_interactions, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :from_user_id, references(:users, on_delete: :delete_all, type: :uuid), null: false
      add :to_user_id, references(:users, on_delete: :delete_all, type: :uuid), null: false
      add :match_id, references(:matches, on_delete: :delete_all, type: :uuid), null: false
      add :data, :jsonb, null: false
    end

    create index(:match_interactions, [:match_id])
  end
end
