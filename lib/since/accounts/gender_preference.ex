defmodule Since.Accounts.GenderPreference do
  use Ecto.Schema

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "gender_preferences" do
    field :user_id, Ecto.UUID, primary_key: true
    # F | M | N
    field :gender, :string
  end
end
