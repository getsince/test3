defmodule T.Repo.Migrations.AddProfilesLastActiveIndex do
  use Ecto.Migration

  def change do
    create index(:profiles, [:last_active])
  end
end
