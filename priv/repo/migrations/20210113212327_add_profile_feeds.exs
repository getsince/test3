defmodule T.Repo.Migrations.AddProfileFeeds do
  use Ecto.Migration

  def change do
    create table(:profile_feeds, primary_key: false) do
      add :user_id, references(:users, on_delete: :delete_all, type: :uuid), primary_key: true
      add :date, :date, primary_key: true
      add :profiles, :jsonb, null: false
      timestamps(updated_at: false)
    end
  end
end
