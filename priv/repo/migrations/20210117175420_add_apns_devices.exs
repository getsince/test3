defmodule T.Repo.Migrations.AddApnsDevices do
  use Ecto.Migration

  @opts [type: :uuid, on_delete: :delete_all]

  def change do
    create table(:apns_devices, primary_key: false) do
      add :user_id, references(:users, @opts), primary_key: true
      add :token_id, references(:users_tokens, @opts), primary_key: true
      add :device_id, :binary, null: false
      add :locale, :string
      add :topic, :string
      add :env, :string

      timestamps()
    end

    create unique_index(:apns_devices, [:device_id])
  end
end
