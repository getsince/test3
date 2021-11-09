defmodule T.Accounts.DistancePreference do
  use Ecto.Schema

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "distance_preferences" do
    field(:user_id, Ecto.UUID, primary_key: true)
    field(:distance, :integer)
  end
end
