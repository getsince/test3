defmodule T.Repo.Migrations.AddTimeslots do
  use Ecto.Migration

  def change do
    create table(:match_timeslot, primary_key: false) do
      add :match_id, references(:matches, type: :uuid, on_delete: :delete_all), primary_key: true
      add :picker_id, references(:users, type: :uuid, on_delete: :delete_all), null: false

      add :slots, {:array, :utc_datetime}, default: []
      add :selected_slot, :utc_datetime

      timestamps(updated_at: false)
    end
  end
end
