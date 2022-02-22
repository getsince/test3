defmodule T.Repo.Migrations.AddLikedProfilesSeen do
  use Ecto.Migration

  def change do
    alter table(:liked_profiles) do
      add :seen, :boolean, default: false, null: false
    end
  end
end
