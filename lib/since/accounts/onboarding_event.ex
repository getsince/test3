defmodule Since.Accounts.OnboardingEvent do
  use Ecto.Schema

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "onboarding_events" do
    field :timestamp, :utc_datetime
    field :user_id, Ecto.Bigflake.UUID
    field :stage, :string
    field :event, :string
  end
end
