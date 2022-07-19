defmodule T.Feeds.CalculatedFeed do
  @moduledoc false
  use Ecto.Schema
  alias T.Accounts.User

  @primary_key {:id, Ecto.Bigflake.UUID, autogenerate: true}
  @foreign_key_type Ecto.Bigflake.UUID
  schema "calculated_feed" do
    belongs_to :for_user, User, primary_key: true
    belongs_to :user, User, primary_key: true
    field :score, :float
  end
end
