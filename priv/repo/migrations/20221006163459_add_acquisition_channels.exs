defmodule Since.Repo.Migrations.AddAcquisitionChannels do
  use Ecto.Migration

  def change do
    create table(:acquisition_channels, primary_key: false) do
      add :user_id, :uuid, null: false
      add :channel, :string
      timestamps(updated_at: false)
    end
  end
end
