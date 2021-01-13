defmodule T.Repo.Migrations.AddSeenProfiles do
  use Ecto.Migration

  @opts [on_delete: :delete_all, type: :uuid]

  def change do
    create table(:seen_profiles, primary_key: false) do
      add :by_user_id, references(:users, @opts), primary_key: true
      add :user_id, references(:users, @opts), primary_key: true
      timestamps(updated_at: false)
    end

    create index(:seen_profiles, [:user_id])
  end
end
