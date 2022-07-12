defmodule T.Repo.Migrations.AddFeedLimits do
  use Ecto.Migration

  def change do
    create table(:feed_limits, primary_key: false) do
      add :user_id, references(:users, on_delete: :delete_all, type: :uuid),
        primary_key: true,
        null: false

      add :timestamp, :utc_datetime, null: false
      add :reached, :boolean, null: false, default: false
    end

    create index(:feed_limits, [:timestamp])
  end
end
