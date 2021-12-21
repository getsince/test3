defmodule T.Matches.MatchContact do
  use Ecto.Schema

  alias T.{Accounts, Matches}

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "match_contact" do
    belongs_to :match, Matches.Match
    belongs_to :picker, Accounts.User

    field :contact_type, :string
    field :value, :string
    field :contacts, :map

    timestamps(updated_at: false)
  end
end
