defmodule T.Matches.Message do
  @moduledoc false
  use Ecto.Schema
  alias T.Matches.Match
  alias T.Accounts.User

  defmodule Text do
    use Ecto.Schema

    embedded_schema do
      field :text, :string
    end
  end

  defmodule Media do
    use Ecto.Schema

    embedded_schema do
      field :s3_key, :string
    end
  end

  defmodule Location do
    use Ecto.Schema

    embedded_schema do
      field :lat, :float
      field :lon, :float
    end
  end

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "match_messages" do
    belongs_to :match, Match, primary_key: true
    field :id, Ecto.Bigflake.UUID, primary_key: true

    belongs_to :author, User

    # field :timestamp, :utc_datetime
    field :kind, :string
    field :data, :map

    timestamps(updated_at: false)
  end
end
