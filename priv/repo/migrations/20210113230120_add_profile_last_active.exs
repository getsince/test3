defmodule T.Repo.Migrations.AddProfileLastActive do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add :last_active, :utc_datetime, null: false, default: "now()"
    end

    # TODO might be expensive
    # TODO can be another table? top ~N user profiles ordered by last_active for the last day (who have been active in the last day)
    create index(:profiles, [~s[date_trunc('day', last_active::timestamp)]])
  end
end
