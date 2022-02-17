defmodule T.Repo.Migrations.CheckedProfiles do
  use Ecto.Migration

  def change do
    create table(:checked_profiles, primary_key: false) do
      add :user_id, references(:profiles, column: :user_id, type: :uuid, on_delete: :delete_all),
        primary_key: true

      add :has_text_contact?, :boolean, null: false
      timestamps()
    end
  end
end
