defmodule T.Repo.Migrations.AddUniqueConstraintOnApnsDeviceId do
  use Ecto.Migration

  def change do
    create unique_index(:apns_devices, [:device_id])
  end
end
