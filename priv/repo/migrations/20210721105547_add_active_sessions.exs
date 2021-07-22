defmodule T.Repo.Migrations.AddActiveSessions do
  use Ecto.Migration

  def change do
    create table(:active_sessions, primary_key: false) do
      # TODO unqie index flake asc
      add :flake, :uuid, null: false
      add :user_id, references(:users, on_delete: :delete_all, type: :uuid), primary_key: true
      add :expires_at, :timestamptz, null: false
    end
  end
end
