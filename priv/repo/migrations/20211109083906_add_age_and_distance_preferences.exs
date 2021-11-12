defmodule T.Repo.Migrations.AddAgesAndDistance do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add :min_age, :integer, null: false
      add :max_age, :integer, null: false
      add :distance, :integer, null: false
      remove :filters
    end

    create index(:profiles, [:min_age])
    create index(:profiles, [:max_age])
    create index(:profiles, [:distance])
  end
end
