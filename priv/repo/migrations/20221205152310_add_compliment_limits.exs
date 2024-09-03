defmodule Since.Repo.Migrations.AddComplimentLimits do
  use Ecto.Migration

  def change do
    create table(:compliment_limits, primary_key: false) do
      add :user_id, references(:users, on_delete: :delete_all, type: :uuid),
        primary_key: true,
        null: false

      add :timestamp, :utc_datetime, null: false
      add :reached, :boolean, null: false, default: false
      add :prompt, :string
    end

    create index(:compliment_limits, [:timestamp])
  end
end
