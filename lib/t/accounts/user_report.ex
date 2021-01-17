defmodule T.Accounts.UserReport do
  use Ecto.Schema
  alias T.Accounts.User

  # TODO test

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "user_reports" do
    belongs_to :on_user, User, primary_key: true
    belongs_to :from_user, User, primary_key: true
    field :reason, :string

    timestamps()
  end
end
