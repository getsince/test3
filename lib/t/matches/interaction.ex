defmodule T.Matches.Interaction do
  @moduledoc false
  use Ecto.Schema
  alias T.Accounts.User
  alias T.Matches.Match

  @primary_key {:id, Ecto.Bigflake.UUID, autogenerate: true}
  @foreign_key_type Ecto.Bigflake.UUID
  schema "match_interactions" do
    belongs_to :from_user, User
    belongs_to :to_user, User
    belongs_to :match, Match
    field :data, :map
    field :seen, :boolean
  end
end
