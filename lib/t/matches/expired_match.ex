defmodule T.Matches.ExpiredMatch do
  @moduledoc false
  use Ecto.Schema

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "expired_matches" do
    field :match_id, Ecto.Bigflake.UUID
    field :user_id, Ecto.Bigflake.UUID
    field :with_user_id, Ecto.Bigflake.UUID
    # TODO
    field :profile, :map, virtual: true

    timestamps(updated_at: false)
  end
end