defmodule T.Repo.Migrations.AddLiveSessions do
  use Ecto.Migration

    def change do
      create table(:live_sessions, primary_key: false) do
        add :flake, :uuid, null: false
        add :user_id, references(:users, on_delete: :delete_all, type: :uuid), primary_key: true
        timestamps(updated_at: false)
      end

      create unique_index(:live_sessions, ["flake asc"])

      drop table("call_invites")
      drop table("active_sessions")
    end
end
