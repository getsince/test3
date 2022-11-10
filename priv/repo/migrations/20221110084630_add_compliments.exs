defmodule T.Repo.Migrations.AddCompliments do
  use Ecto.Migration

  @opts [on_delete: :delete_all, type: :uuid]

  def change do
    create table(:compliments, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :from_user_id, references(:users, @opts), null: false
      add :to_user_id, references(:users, @opts), null: false
      add :data, :jsonb, null: false
      add :seen, :boolean, null: false, default: false
      add :revealed, :boolean, null: false, default: false
      timestamps(updated_at: false)
    end

    create index(:compliments, [:to_user_id])
  end
end
