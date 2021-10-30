defmodule T.Repo.Migrations.AddBirthdateToProfiles do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add :birthdate, :date
    end

    create index(:profiles, [:birthdate], where: "birthdate is not null")
  end
end
