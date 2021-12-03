defmodule T.Repo.Migrations.AddMatchArchivation do
  use Ecto.Migration

  @opts [on_delete: :delete_all, type: :uuid]

  def change do
    alter table(:matches) do
      add :archived_by, :uuid
      add :archived_by_both, :boolean
    end

    create table(:matches_pending_archivation, primary_key: false) do
      add :match_id, references(:matches, @opts), primary_key: true, null: false
      add :by_user_id, references(:users, @opts), null: false
      timestamps(updated_at: false)
    end

    create index(:matches_pending_archivation, [:match_id, :by_user_id])
  end
end
