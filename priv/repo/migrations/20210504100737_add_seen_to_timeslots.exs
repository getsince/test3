defmodule T.Repo.Migrations.AddSeenToTimeslots do
  use Ecto.Migration

  def change do
    alter table(:match_timeslot) do
      add :seen?, :boolean
    end
  end
end
