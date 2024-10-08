defmodule Since.Games.Compliment do
  @moduledoc false
  use Ecto.Schema
  alias Since.Accounts.User

  @primary_key {:id, Ecto.Bigflake.UUID, autogenerate: true}
  @foreign_key_type Ecto.Bigflake.UUID
  schema "compliments" do
    belongs_to :from_user, User
    belongs_to :to_user, User
    field :prompt, :string
    field :profile, :map, virtual: true
    field :seen, :boolean
    field :revealed, :boolean
    timestamps(updated_at: false)
  end
end
