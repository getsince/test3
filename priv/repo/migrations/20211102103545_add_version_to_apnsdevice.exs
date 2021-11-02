defmodule T.Repo.Migrations.AddVersionToApnsdevice do
  use Ecto.Migration

  def change do
    alter table(:apns_devices) do
      add :version, :string
    end

  end
end
