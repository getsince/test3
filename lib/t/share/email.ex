defmodule T.Share.Email do
  use Ecto.Schema

  @primary_key false
  schema "emails" do
    field :email, :string
  end
end
