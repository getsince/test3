defmodule T.Feeds.LiveInvite do
  @moduledoc false
  use Ecto.Schema
  alias T.Accounts.User

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "live_invites" do
    belongs_to :by_user, User, primary_key: true
    belongs_to :user, User, primary_key: true

    timestamps(updated_at: false)
  end
end
