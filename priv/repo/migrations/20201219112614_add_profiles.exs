defmodule Since.Repo.Migrations.AddProfiles do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS postgis",
            "DROP EXTENSION IF EXISTS postgis"

    create table(:profiles, primary_key: false) do
      add :user_id, references(:users, on_delete: :delete_all, type: :uuid), primary_key: true
      add :name, :text
      add :gender, :text
      add :birthdate, :date
      add :location, :"geography(Point,4326)"
      add :hidden?, :boolean, null: false, default: true
      add :last_active, :utc_datetime, null: false
      add :story, :jsonb
      add :min_age, :integer
      add :max_age, :integer
      add :distance, :integer
      add :times_liked, :integer, null: false, default: 0
      add :times_shown, :integer, null: false, default: 0
      add :like_ratio, :float, null: false, default: 0
    end

    # TODO has a high ration of nulls, maybe add `where: "location is not null"`
    create index(:profiles, [:location], using: "GIST")
    create index(:profiles, [:last_active])
    create index(:profiles, [:birthdate], where: "birthdate is not null")
    create index(:profiles, [:like_ratio])
    # TODO is not used according to pg stats
    create index(:profiles, [:min_age], where: "min_age is not null")
    # TODO is not used according to pg stats
    create index(:profiles, [:max_age], where: "max_age is not null")
    # TODO is not used according to pg stats
    create index(:profiles, [:distance], where: "distance is not null")
  end
end
