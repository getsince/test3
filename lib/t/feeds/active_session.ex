defmodule T.Feeds.ActiveSession do
  use Ecto.Schema
  alias T.Accounts.User

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "active_sessions" do
    belongs_to :user, User, primary_key: true
    field :expires_at, :utc_datetime
    timestamps()
  end
end
