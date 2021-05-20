defmodule T.Repo.Migrations.AddProfileLocation do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add :location, :"geography(Point,4326)"
    end

    create index(:profiles, [:location], using: "GIST")
  end
end
