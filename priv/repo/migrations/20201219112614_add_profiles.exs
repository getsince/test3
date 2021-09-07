defmodule T.Repo.Migrations.AddProfiles do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS postgis",
            "DROP EXTENSION IF EXISTS postgis"

    create table(:profiles, primary_key: false) do
      add :user_id, references(:users, on_delete: :delete_all, type: :uuid), primary_key: true
      add :name, :text
      add :gender, :text
      add :location, :"geography(Point,4326)"
      add :hidden?, :boolean, null: false, default: true
      add :last_active, :utc_datetime, null: false
      add :story, :jsonb
      add :filters, :jsonb, default: "{}"
    end

    create index(:profiles, [:location], using: "GIST")
  end
end
