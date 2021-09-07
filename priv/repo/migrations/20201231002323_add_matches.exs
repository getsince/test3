defmodule T.Repo.Migrations.AddMatches do
  use Ecto.Migration

  @opts [on_delete: :delete_all, type: :uuid]

  def change do
    create table(:matches, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id_1, references(:users, @opts), null: false
      add :user_id_2, references(:users, @opts), null: false
      timestamps(updated_at: false)
    end

    create unique_index(:matches, [:user_id_1, :user_id_2])
  end
end
