defmodule T.Repo.Migrations.AddUniqueDeviceIdsIndex do
  use Ecto.Migration

  def change do
    create unique_index(:apns_devices, [:device_id])
    create unique_index(:pushkit_devices, [:device_id])
  end
end
