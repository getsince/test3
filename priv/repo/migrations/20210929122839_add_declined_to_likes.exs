defmodule T.Repo.Migrations.AddDeclinedToLikes do
  use Ecto.Migration

  def change do
    alter table(:liked_profiles) do
      add :declined, :boolean
    end
  end
end
