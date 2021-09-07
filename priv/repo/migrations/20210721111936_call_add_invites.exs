defmodule T.Repo.Migrations.AddCallInvites do
  use Ecto.Migration

  # TODO add flake
  # TODO unqie index flake asc

  @opts [on_delete: :delete_all, column: :user_id, type: :uuid]

  def change do
    create table(:call_invites, primary_key: false) do
      add :by_user_id, references(:active_sessions, @opts), primary_key: true
      add :user_id, references(:active_sessions, @opts), primary_key: true

      timestamps(updated_at: false)
    end
  end
end
