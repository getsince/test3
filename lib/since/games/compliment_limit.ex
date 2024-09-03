defmodule Since.Games.ComplimentLimit do
  use Ecto.Schema

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "compliment_limits" do
    belongs_to :user, Since.Accounts.User, primary_key: true
    field :timestamp, :utc_datetime
    field :reached, :boolean
    field :prompt, :string
  end
end
