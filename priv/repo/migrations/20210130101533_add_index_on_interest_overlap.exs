defmodule T.Repo.Migrations.AddIndexOnInterestOverlap do
  use Ecto.Migration

  def change do
    create index(:interests_overlap, [:user_id_1, :user_id_2, "score desc"], where: "score > 0")
    create index(:interests_overlap, [:user_id_2, :user_id_1, "score desc"], where: "score > 0")
  end
end
