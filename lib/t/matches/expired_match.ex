defmodule T.Matches.ExpiredMatch do
  @moduledoc false
  use Ecto.Schema

  @foreign_key_type Ecto.Bigflake.UUID
  schema "expired_matches" do
    field :user_id, Ecto.Bigflake.UUID
    field :with_user_id, Ecto.Bigflake.UUID
    # TODO
    field :profile, :map, virtual: true
    field :expiration_date, :map, virtual: true

    timestamps(updated_at: false)
  end
end
