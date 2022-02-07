defmodule T.Events.Event do
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, Ecto.Bigflake.UUID, autogenerate: true}
  schema "events" do
    field :name, :string
    field :actor, Ecto.Bigflake.UUID
    field :data, :map
  end
end
