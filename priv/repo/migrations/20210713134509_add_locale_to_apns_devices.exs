defmodule T.Repo.Migrations.AddLocaleToApnsDevices do
  use Ecto.Migration

  def change do
    alter table(:apns_devices) do
      add :locale, :string
    end
  end
end
