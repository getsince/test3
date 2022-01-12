defmodule T.Calls.Voicemail do
  @moduledoc false
  use Ecto.Schema

  alias T.Accounts.User
  alias T.Matches.Match

  @primary_key {:id, Ecto.Bigflake.UUID, autogenerate: true}
  @foreign_key_type Ecto.Bigflake.UUID
  schema "match_voicemail" do
    belongs_to :caller, User
    belongs_to :match, Match
    field :s3_key, :string
    field :listened_at, :utc_datetime
    timestamps(updated_at: false)
  end
end
