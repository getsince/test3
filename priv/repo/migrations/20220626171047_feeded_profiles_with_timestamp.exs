defmodule Since.Repo.Migrations.FeededProfilesWithTimestamp do
  use Ecto.Migration

  @opts [on_delete: :delete_all, type: :uuid]

  def change do
    drop table(:feeded_profiles)

    flush()

    create table(:feeded_profiles, primary_key: false) do
      add :for_user_id, references(:users, @opts), primary_key: true, null: false
      add :user_id, references(:users, @opts), primary_key: true, null: false
      timestamps(updated_at: false)
    end
  end
end
