defmodule T.Repo.Migrations.DropDislikes do
  use Ecto.Migration

  def change do
    drop table(:disliked_profiles)
  end
end
