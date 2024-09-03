defmodule Since.Feeds.Meeting do
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, Ecto.Bigflake.UUID, autogenerate: true}
  @foreign_key_type Ecto.Bigflake.UUID
  schema "meetings" do
    belongs_to :user, Since.Accounts.User, primary_key: false
    field :data, :map
    # TODO ?
    field :profile, :map, virtual: true

    timestamps(updated_at: false)
  end
end
