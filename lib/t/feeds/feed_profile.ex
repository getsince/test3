defmodule T.Feeds.FeedProfile do
  use Ecto.Schema

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "profiles" do
    belongs_to :user, T.Accounts.User, primary_key: true
    field :name, :string
    field :story, {:array, :map}
    field :hidden?, :boolean
    field :last_active, :utc_datetime
    field :location, Geo.PostGIS.Geometry
    field :distance, :integer, virtual: true
    # F | M | N
    field :gender, :string
    field :birthdate, :date
    field :times_liked, :integer
    field :times_shown, :integer
    field :like_ratio, :float
  end
end
