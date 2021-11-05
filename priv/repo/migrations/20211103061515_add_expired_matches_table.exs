defmodule T.Repo.Migrations.AddExpiredMatchesTable do
  use Ecto.Migration

  @opts [on_delete: :delete_all, type: :uuid]

  def change do
    create table(:expired_matches, primary_key: false) do
      add :match_id, :uuid, null: false
      add :user_id, references(:users, @opts), null: false
      add :with_user_id, references(:users, @opts), null: false

      timestamps(updated_at: false)
    end

    create unique_index(:expired_matches, [:user_id, :match_id])
  end
end
