defmodule T.Matches.MatchEvent do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Query

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "match_events" do
    field :timestamp, :utc_datetime
    field :match_id, Ecto.Bigflake.UUID
    field :event, :string
  end
end
