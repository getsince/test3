defmodule T.Feeds.LiveSession do
  use Ecto.Schema

  @primary_key {:flake, Ecto.Bigflake.UUID, autogenerate: true}
  @foreign_key_type Ecto.Bigflake.UUID
  schema "live_sessions" do
    belongs_to :user, T.Accounts.User, primary_key: true
    timestamps(updated_at: false)
  end
end
