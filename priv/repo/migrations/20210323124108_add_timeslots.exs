defmodule T.Repo.Migrations.AddTimeslots do
  use Ecto.Migration

  @opts [type: :uuid, on_delete: :delete_all]

  def change do
    create table(:match_timeslot, primary_key: false) do
      add :match_id, references(:matches, @opts), primary_key: true
      add :picker_id, references(:users, @opts), null: false

      add :slots, {:array, :utc_datetime}, default: []
      add :selected_slot, :utc_datetime

      timestamps(updated_at: false)
    end
  end
end
