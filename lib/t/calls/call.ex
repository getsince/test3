defmodule T.Calls.Call do
  use Ecto.Schema
  alias T.Accounts.User

  @primary_key {:id, Ecto.Bigflake.UUID, autogenerate: true}
  @foreign_key_type Ecto.Bigflake.UUID
  schema "calls" do
    belongs_to :caller, User
    belongs_to :called, User

    field :ended_by, Ecto.Bigflake.UUID
    field :ended_at, :utc_datetime
    field :accepted_at, :utc_datetime

    timestamps(updated_at: false)
  end
end
