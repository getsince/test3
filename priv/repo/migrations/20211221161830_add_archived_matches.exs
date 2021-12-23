defmodule T.Repo.Migrations.AddArchivedMatches do
  use Ecto.Migration

  @opts [on_delete: :delete_all, type: :uuid]

  def change do
    create table(:archived_matches, primary_key: false) do
      add :match_id, :uuid, null: false
      add :by_user_id, references(:users, @opts), null: false
      add :with_user_id, references(:users, @opts), null: false

      timestamps(updated_at: false)
    end

    create unique_index(:archived_matches, [:by_user_id, :match_id])
  end
end
