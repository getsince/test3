defmodule Since.Repo.Migrations.AddMatchEvents do
  use Ecto.Migration

  # TODO remove?
  def change do
    create table(:match_events, primary_key: false) do
      add :timestamp, :utc_datetime, null: false
      add :match_id, :uuid, null: false
      add :event, :string, null: false
    end

    create index(:match_events, [:match_id, "timestamp desc"])
    create index(:match_events, ["event"], where: "event = 'call_start'")
  end
end
