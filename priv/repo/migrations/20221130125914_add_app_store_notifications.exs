defmodule T.Repo.Migrations.AddAppStoreNotifications do
  use Ecto.Migration

  def change do
    create table(:app_store_notifications, primary_key: false) do
      add :notification_uuid, :uuid, primary_key: true
      add :signed_date, :utc_datetime, null: false
      add :user_id, :uuid
      add :notification_type, :string, null: false
      add :subtype, :string, null: true
      add :purchase_date, :utc_datetime
      add :expires_date, :utc_datetime
      add :transaction_id, :string
      add :original_transaction_id, :string, null: false
      add :original_purchase_date, :utc_datetime
      add :revocation_date, :utc_datetime
      add :revocation_reason, :integer
      add :data, :jsonb
    end

    create index(:app_store_notifications, ["signed_date desc"])
    create index(:app_store_notifications, [:user_id])
  end
end
