defmodule T.Chats.Chat do
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, Ecto.Bigflake.UUID, autogenerate: true}
  @foreign_key_type Ecto.Bigflake.UUID
  schema "chats" do
    field :user_id_1, Ecto.Bigflake.UUID
    field :user_id_2, Ecto.Bigflake.UUID

    # TODO ?
    field :profile, :map, virtual: true

    field :messages, {:array, :map}, virtual: true
    field :matched, :boolean, default: false

    timestamps(updated_at: false)
  end
end
