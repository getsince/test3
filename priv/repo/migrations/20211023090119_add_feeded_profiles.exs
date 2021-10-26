defmodule T.Repo.Migrations.AddFeededProfiles do
  use Ecto.Migration

  @opts [on_delete: :delete_all, type: :uuid]

  def change do
    create table(:feeded_profiles, primary_key: false) do
      add :for_user_id, references(:users, @opts), primary_key: true, null: false
      add :user_id, references(:users, @opts), primary_key: true, null: false
    end
  end
end
