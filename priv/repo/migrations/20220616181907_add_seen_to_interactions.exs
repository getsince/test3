defmodule Since.Repo.Migrations.AddSeenToInteractions do
  use Ecto.Migration

  def change do
    alter table(:match_interactions) do
      add :seen, :boolean, null: false, default: false
    end
  end
end
