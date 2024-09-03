defmodule Since.Repo.Migrations.AddPremiumToProfiles do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add :premium, :boolean, null: false, default: false
    end
  end
end
