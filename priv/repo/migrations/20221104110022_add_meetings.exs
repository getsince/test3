defmodule Since.Repo.Migrations.AddMeetings do
  use Ecto.Migration

  @opts [on_delete: :delete_all, type: :uuid]

  def change do
    create table(:meetings, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, references(:users, @opts), null: false
      add :data, :jsonb, null: false
      timestamps(updated_at: false)
    end
  end
end
