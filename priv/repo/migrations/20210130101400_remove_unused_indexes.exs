defmodule T.Repo.Migrations.RemoveUnusedIndexes do
  use Ecto.Migration

  def change do
    drop index(:disliked_profiles, [:user_id, :by_user_id])
    drop index(:seen_profiles, [:user_id])
  end
end
