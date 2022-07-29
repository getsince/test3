defmodule T.Feeds.FeededProfile do
  @moduledoc false
  use Ecto.Schema
  alias T.Accounts.User

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "feeded_profiles" do
    belongs_to :for_user, User, primary_key: true
    belongs_to :user, User, primary_key: true
    timestamps(updated_at: false)
  end
end
