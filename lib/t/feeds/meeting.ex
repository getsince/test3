defmodule T.Feeds.Meeting do
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, Ecto.Bigflake.UUID, autogenerate: true}
  @foreign_key_type Ecto.Bigflake.UUID
  schema "meetings" do
    field :user_id, Ecto.Bigflake.UUID
    field :data, :map
    # TODO ?
    field :profile, :map, virtual: true

    timestamps(updated_at: false)
  end
end
