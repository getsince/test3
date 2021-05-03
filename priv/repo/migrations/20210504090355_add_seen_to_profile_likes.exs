defmodule T.Repo.Migrations.AddSeenToProfileLikes do
  use Ecto.Migration

  def change do
    alter table(:liked_profiles) do
      add :seen?, :boolean
    end
  end
end
