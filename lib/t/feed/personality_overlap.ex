defmodule T.Feeds.PersonalityOverlap do
  @moduledoc false
  use Ecto.Schema

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "interests_overlap" do
    field :user_id_1, Ecto.Bigflake.UUID
    field :user_id_2, Ecto.Bigflake.UUID
    field :score, :integer
    timestamps()
  end
end
