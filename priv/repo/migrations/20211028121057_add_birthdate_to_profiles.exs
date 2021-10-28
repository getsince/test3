defmodule T.Repo.Migrations.AddBirthdayToProfiles do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add :birthday, :utc_datetime, default: nil
    end

    create index(:profiles, [:birthday])
  end
end
