defmodule T.Repo.Migrations.AddTimeslotsAcceptedAt do
  use Ecto.Migration
  import Ecto.Query
  alias T.Repo

  def change do
    alter table(:match_timeslot) do
      add :accepted_at, :utc_datetime
    end

    flush()

    "match_timeslot"
    |> where([t], not is_nil(t.selected_slot))
    |> update([t], set: [accepted_at: t.inserted_at])
    |> Repo.update_all([])
  end
end
