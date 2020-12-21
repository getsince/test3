defmodule T.Repo.Migrations.AddAuthTables do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :phone_number, :string, null: false
      timestamps()
    end

    create unique_index(:users, [:phone_number])

    create table(:users_tokens, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :uuid), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])
  end
end
