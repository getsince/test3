defmodule T.Matches.MatchEvents do
  @moduledoc false
  use Ecto.Schema

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "match_events" do
    field :timestamp, :utc_datetime
    field :match_id, Ecto.Bigflake.UUID, primary_key: true
    field :event, :string
  end
end
