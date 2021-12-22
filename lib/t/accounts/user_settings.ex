defmodule T.Accounts.UserSettings do
  use Ecto.Schema

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "user_settings" do
    belongs_to :user, T.Accounts.User, primary_key: true
    field :audio_only, :boolean
  end
end
