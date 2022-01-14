defmodule T.Matches.Timeslot do
  use Ecto.Schema

  alias T.{Accounts, Matches}

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "match_timeslot" do
    belongs_to :match, Matches.Match, primary_key: true
    belongs_to :picker, Accounts.User

    field :slots, {:array, :utc_datetime}
    field :selected_slot, :utc_datetime
    field :accepted_at, :utc_datetime

    timestamps(updated_at: false)
  end
end
