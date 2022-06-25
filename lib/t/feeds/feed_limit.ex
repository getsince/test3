defmodule T.Feeds.FeedLimit do
  use Ecto.Schema

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "feed_limits" do
    belongs_to :user, T.Accounts.User, primary_key: true
    field :timestamp, :utc_datetime
    field :reached, :boolean
  end
end
