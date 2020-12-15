defmodule T.Visits.Visit do
  use Ecto.Schema

  @primary_key false
  schema "visits" do
    field :id, Ecto.UUID
    field :meta, :map
    timestamps(updated_at: false)
  end
end
