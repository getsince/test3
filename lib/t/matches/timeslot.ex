defmodule T.Matches.Timeslot do
  use Ecto.Schema

  alias T.{Accounts, Matches}

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "match_timeslot" do
    belongs_to :match, Matches.Match
    belongs_to :picker, Accounts.User

    field :slots, {:array, :utc_datetime}
    field :selected_slot, :utc_datetime
    field :seen?, :boolean

    timestamps(updated_at: false)
  end
end
