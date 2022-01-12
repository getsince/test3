defmodule T.Matches.MatchContact do
  use Ecto.Schema

  alias T.{Accounts, Matches}

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "match_contact" do
    belongs_to :match, Matches.Match
    belongs_to :picker, Accounts.User

    field :contacts, :map
    field :opened_contact_type, :string
    field :seen_at, :utc_datetime

    timestamps(updated_at: false)
  end
end
