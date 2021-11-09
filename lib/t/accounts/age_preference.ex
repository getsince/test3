defmodule T.Accounts.AgePreference do
  use Ecto.Schema

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "age_preferences" do
    field(:user_id, Ecto.UUID, primary_key: true)
    field(:min_age, :integer)
    field(:max_age, :integer)
  end
end
