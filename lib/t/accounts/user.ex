defmodule T.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  alias T.Accounts.{Profile, UserSettings}

  # https://hexdocs.pm/pow/lock_users.html#content

  @primary_key {:id, Ecto.Bigflake.UUID, autogenerate: true}
  @foreign_key_type Ecto.Bigflake.UUID
  schema "users" do
    field :apple_id, :string
    field :email, :string

    field :onboarded_at, :utc_datetime
    field :onboarded_with_story_at, :utc_datetime
    field :blocked_at, :utc_datetime

    has_one :profile, Profile
    has_one :settings, UserSettings
    timestamps()
  end

  def apple_id_registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:apple_id, :email])
    |> validate_required([:apple_id])
    |> unsafe_validate_unique(:apple_id, T.Repo)
    |> unique_constraint(:apple_id)
  end
end
