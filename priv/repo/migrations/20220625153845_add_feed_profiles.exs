defmodule T.Repo.Migrations.AddFeedProfiles do
  use Ecto.Migration

  @opts [on_delete: :delete_all, type: :uuid]

  def change do
    create table(:feed_profiles, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :for_user_id, references(:users, @opts), primary_key: true, null: false
      add :user_id, references(:users, @opts), primary_key: true, null: false
    end
  end
end
