defmodule T.Repo.Migrations.AddApnsDevices do
  use Ecto.Migration

  def change do
    create table(:apns_devices, primary_key: false) do
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), primary_key: true

      add :token_id, references(:users_tokens, type: :uuid, on_delete: :delete_all),
        primary_key: true

      add :device_id, :binary, null: false

      timestamps()
    end
  end
end
