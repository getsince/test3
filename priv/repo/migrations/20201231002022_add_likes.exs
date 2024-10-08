defmodule Since.Repo.Migrations.AddLikes do
  use Ecto.Migration

  @opts [on_delete: :delete_all, type: :uuid]

  def change do
    create table(:liked_profiles, primary_key: false) do
      add :by_user_id, references(:users, @opts), primary_key: true
      add :user_id, references(:users, @opts), primary_key: true
      add :declined, :boolean
      add :seen, :boolean, default: false, null: false
      timestamps(updated_at: false)
    end

    create index(:liked_profiles, [:user_id, :by_user_id])
  end
end
