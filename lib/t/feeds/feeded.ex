defmodule T.Feeds.Feeded do
  @moduledoc false
  use Ecto.Schema
  alias T.Accounts.User

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "profile_feeds" do
    belongs_to :user, User, primary_key: true
    belongs_to :feeded, User, primary_key: true
  end
end
