defmodule T.Repo.Migrations.DropInterestsOverlap do
  use Ecto.Migration

  def up do
    drop table(:interests_overlap)
  end
end
