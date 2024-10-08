defmodule Since.Repo.Migrations.AddCalculatedFeed do
  use Ecto.Migration

  def change do
    create table(:calculated_feed, primary_key: false) do
      add :for_user_id, :uuid, null: false
      add :user_id, :uuid, null: false
      add :score, :float, null: false
    end

    create index(:calculated_feed, [:for_user_id])
  end
end
