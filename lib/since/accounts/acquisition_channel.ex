defmodule Since.Accounts.AcquisitionChannel do
  use Ecto.Schema

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "acquisition_channels" do
    field :user_id, Ecto.Bigflake.UUID
    field :channel, :string
    timestamps(updated_at: false)
  end
end
