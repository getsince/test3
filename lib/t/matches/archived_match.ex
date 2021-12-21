defmodule T.Matches.ArchivedMatch do
  @moduledoc false
  use Ecto.Schema

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "archived_matches" do
    field :match_id, Ecto.Bigflake.UUID
    field :by_user_id, Ecto.Bigflake.UUID
    field :with_user_id, Ecto.Bigflake.UUID
    # TODO
    field :profile, :map, virtual: true

    timestamps(updated_at: false)
  end
end
