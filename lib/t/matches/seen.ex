defmodule T.Matches.Seen do
  use Ecto.Schema

  @primary_key false
  schema "matches_seen" do
    field :user_id, Ecto.Bigflake.UUID, primary_key: true
    field :match_id, Ecto.Bigflake.UUID, primary_key: true
  end
end
