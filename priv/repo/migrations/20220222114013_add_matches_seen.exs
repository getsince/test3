defmodule Since.Repo.Migrations.AddMatchesSeen do
  use Ecto.Migration

  def change do
    create table(:matches_seen, primary_key: false) do
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), primary_key: true
      add :match_id, references(:matches, type: :uuid, on_delete: :delete_all), primary_key: true
    end
  end
end
