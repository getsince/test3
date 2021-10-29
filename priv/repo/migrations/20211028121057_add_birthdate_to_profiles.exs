defmodule T.Repo.Migrations.AddBirthdateToProfiles do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add :birthdate, :utc_datetime, default: nil
    end

    create index(:profiles, [:birthdate])
  end
end
