defmodule T.Repo.Migrations.AddAgesAndDistance do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add :min_age, :integer
      add :max_age, :integer
      add :distance, :integer
      remove :filters
    end

    create index(:profiles, [:min_age])
    create index(:profiles, [:max_age])
    create index(:profiles, [:distance])
  end
end
