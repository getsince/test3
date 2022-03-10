defmodule T.Matches.Like do
  @moduledoc false
  use Ecto.Schema
  alias T.Accounts.User

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "liked_profiles" do
    belongs_to :by_user, User, primary_key: true
    belongs_to :user, User, primary_key: true

    field :liker_profile, :map, virtual: true
    field :declined, :boolean
    field :seen, :boolean

    timestamps(updated_at: false)
  end
end
