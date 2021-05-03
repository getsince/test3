defmodule T.Matches.SeenMatch do
  @moduledoc false
  use Ecto.Schema
  alias T.Accounts.User
  alias T.Matches.Match

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "seen_matches" do
    belongs_to :by_user, User, primary_key: true
    belongs_to :match, Match, primary_key: true
    timestamps(updated_at: false)
  end
end
