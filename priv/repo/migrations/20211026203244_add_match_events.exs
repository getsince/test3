defmodule T.Repo.Migrations.AddMatchEvents do
  use Ecto.Migration

  import Ecto.Query

  def change do
    create table(:match_events, primary_key: false) do
      add :timestamp, :utc_datetime, null: false
      add :match_id, :uuid, null: false
      add :event, :string, null: false
    end

    create index(:match_events, ["timestamp desc"])

    flush()

    match_created_events =
      "matches"
      |> select([m], {m.id, m.inserted_at})
      |> T.Repo.all()
      |> Enum.map(fn {match_id, created_at} ->
        %{
          timestamp: DateTime.from_naive!(created_at, "Etc/UTC"),
          match_id: match_id,
          event: "created"
        }
      end)

    T.Repo.insert_all("match_events", match_created_events)

    match_created_events =
      "matches"
      |> select([m], {m.id})
      |> T.Repo.all()
      |> Enum.map(fn {match_id} ->
        %{timestamp: DateTime.utc_now(), match_id: match_id, event: "keepalive"}
      end)

    T.Repo.insert_all("match_events", match_created_events)
  end
end