defmodule T.Repo.Migrations.AddLikesAndDislikes do
  use Ecto.Migration

  @opts [on_delete: :delete_all, type: :uuid]

  # TODO can be a single table "reaction"?
  def change do
    create table(:liked_profiles, primary_key: false) do
      add :by_user_id, references(:users, @opts), primary_key: true
      add :user_id, references(:users, @opts), primary_key: true
      timestamps(updated_at: false)
    end

    create index(:liked_profiles, [:user_id, :by_user_id])

    create table(:disliked_profiles, primary_key: false) do
      add :by_user_id, references(:users, @opts), primary_key: true
      add :user_id, references(:users, @opts), primary_key: true
      timestamps(updated_at: false)
    end

    create index(:disliked_profiles, [:user_id, :by_user_id])
  end
end
