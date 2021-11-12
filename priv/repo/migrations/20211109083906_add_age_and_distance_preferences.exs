defmodule T.Repo.Migrations.AddAgesAndDistance do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add :min_age, :integer, default: 18, null: false
      add :max_age, :integer, default: 100, null: false
      add :distance, :integer, default: 20000, null: false
      remove :filters
    end

    create index(:profiles, [:min_age], where: "min_age is not null")
    create index(:profiles, [:max_age], where: "max_age is not null")
    create index(:profiles, [:distance], where: "distance is not null")
  end
end
