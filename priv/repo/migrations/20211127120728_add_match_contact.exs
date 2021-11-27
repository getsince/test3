defmodule T.Repo.Migrations.AddMatchContact do
  use Ecto.Migration

  @opts [on_delete: :delete_all, type: :uuid]

  def change do
    create table(:match_contact, primary_key: false) do
      add :match_id, :uuid, null: false
      add :by_user_id, references(:users, @opts), primary_key: true, null: false
      add :contact_type, :string, null: false
      add :value, :string, null: false
      timestamps(updated_at: false)
    end

    create index(:match_contact, [:match_id, :by_user_id])
  end
end
