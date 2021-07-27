defmodule T.Feeds.FeedProfile do
  use Ecto.Schema

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "profiles" do
    belongs_to :user, T.Accounts.User, primary_key: true
    field :name, :string
    field :story, {:array, :map}
    field :hidden?, :boolean
    field :song, :map
  end
end
