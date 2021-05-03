defmodule T.Repo.Migrations.AddSeenMatches do
  use Ecto.Migration

  @opts [on_delete: :delete_all, type: :uuid]

  def change do
    create table(:seen_matches, primary_key: false) do
      add :by_user_id, references(:users, @opts), primary_key: true
      add :match_id, references(:matches, @opts), primary_key: true
      timestamps(updated_at: false)
    end
  end
end
