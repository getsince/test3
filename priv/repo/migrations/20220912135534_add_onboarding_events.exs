defmodule T.Repo.Migrations.AddOnboardingEvents do
  use Ecto.Migration

  def change do
    create table(:onboarding_events, primary_key: false) do
      add :timestamp, :utc_datetime, null: false
      add :user_id, :uuid, null: false
      add :stage, :string, null: false
      add :event, :string, null: false
    end

    create index(:onboarding_events, [:user_id, "timestamp desc"])
  end
end
