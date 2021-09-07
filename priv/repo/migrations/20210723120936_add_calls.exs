defmodule T.Repo.Migrations.AddCalls do
  use Ecto.Migration

  @opts [on_delete: :delete_all, type: :uuid, column: :user_id]

  def change do
    create table(:calls, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :caller_id, references(:profiles, @opts), null: false
      add :called_id, references(:profiles, @opts), null: false
      add :ended_at, :timestamptz
      add :accepted_at, :timestamptz

      timestamps(updated_at: false)
    end
  end
end
