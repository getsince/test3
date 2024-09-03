defmodule Since.Repo.Migrations.AddAddressToProfiles do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add :address, :jsonb
    end
  end
end
