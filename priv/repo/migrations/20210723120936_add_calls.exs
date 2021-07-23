defmodule T.Repo.Migrations.AddCalls do
  use Ecto.Migration

  def change do
    create table(:calls, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :caller_id, references(:profiles, on_delete: :delete_all, column: :user_id, type: :uuid), null: false
      add :called_id, references(:profiles, on_delete: :delete_all, column: :user_id, type: :uuid), null: false

      add :ended_at, :timestamptz

      timestamps(updated_at: false)
    end
  end
end
