defmodule T.Share.Phone do
  use Ecto.Schema

  @primary_key false
  schema "phones" do
    field :phone_number, :string
    field :meta, :map
    timestamps(updated_at: false)
  end
end
