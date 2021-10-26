defmodule T.Repo.Migrations.AddMatchEvents do
  use Ecto.Migration

  def change do
    create table(:match_events, primary_key: false) do
      add :timestamp, :utc_datetime, null: false
      add :match_id, :uuid, null: false
      add :event, :string, null: false
    end
    create index(:match_events, ["timestamp desc"])

  end
end
