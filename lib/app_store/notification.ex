defmodule AppStore.Notification do
  use Ecto.Schema

  @primary_key false
  schema "app_store_notifications" do
    field(:notification_uuid, Ecto.Bigflake.UUID, primary_key: true)
    field(:signed_date, :utc_datetime)
    field(:user_id, Ecto.Bigflake.UUID)
    field(:notification_type, :string)
    field(:subtype, :string)
    field(:purchase_date, :utc_datetime)
    field(:expires_date, :utc_datetime)
    field(:transaction_id, :string)
    field(:original_transaction_id, :string)
    field(:original_purchase_date, :utc_datetime)
    field(:revocation_date, :utc_datetime)
    field(:revocation_reason, :integer)
    field(:data, :map)
  end
end
