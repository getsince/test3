defmodule T.Feeds.Feed do
  @moduledoc false
  use Ecto.Schema
  alias T.Accounts.User

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "profile_feeds" do
    belongs_to :user, User, primary_key: true
    field :date, :date, primary_key: true
    field :profiles, :map
    timestamps(updated_at: false)
  end
end
