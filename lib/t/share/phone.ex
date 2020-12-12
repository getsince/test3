defmodule T.Share.Phone do
  use Ecto.Schema

  @primary_key false
  schema "phones" do
    field :phone_number, :string
  end
end
