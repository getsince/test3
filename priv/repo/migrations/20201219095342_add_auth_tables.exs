defmodule T.Repo.Migrations.AddAuthTables do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :apple_id, :string
      add :email, :string
      add :blocked_at, :utc_datetime
      add :onboarded_at, :utc_datetime
      add :onboarded_with_story_at, :utc_datetime
      timestamps()
    end

    # TODO need where?
    create unique_index(:users, [:apple_id], where: "apple_id is not null")

    create table(:users_tokens, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :uuid), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      add :version, :string
      timestamps(updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])
  end
end
