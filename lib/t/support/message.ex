defmodule T.Support.Message do
  @moduledoc false
  use Ecto.Schema
  alias T.Accounts.User

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "support_messages" do
    belongs_to :user, User
    field :id, Ecto.Bigflake.UUID, primary_key: true

    belongs_to :author, User

    # field :timestamp, :utc_datetime
    field :kind, :string
    field :data, :map

    timestamps(updated_at: false)
  end
end
