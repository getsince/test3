defmodule T.Accounts.PushKitDevice do
  use Ecto.Schema
  alias T.Accounts.{User, UserToken}

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "pushkit_devices" do
    belongs_to :user, User, primary_key: true
    belongs_to :token, UserToken, primary_key: true
    field :device_id, :binary
    field :topic, :string
    # prod | sandbox
    field :env, :string
    timestamps()
  end
end
