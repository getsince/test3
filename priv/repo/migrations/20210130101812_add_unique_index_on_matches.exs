defmodule T.Repo.Migrations.AddUniqueIndexOnMatches do
  use Ecto.Migration

  def change do
    create unique_index(:matches, [:user_id_1, :user_id_2])
  end
end
