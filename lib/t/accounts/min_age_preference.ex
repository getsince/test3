defmodule T.Accounts.MinAgePreference do
  use Ecto.Schema

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "min_age_preferences" do
    field :user_id, Ecto.UUID, primary_key: true
    field :age, :integer
  end
end
