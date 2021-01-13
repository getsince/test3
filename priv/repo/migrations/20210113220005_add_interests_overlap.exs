defmodule T.Repo.Migrations.AddInterestsOverlap do
  use Ecto.Migration

  @opts [type: :uuid, on_delete: :delete_all]

  def change do
    create table(:interests_overlap, primary_key: false) do
      add :user_id_1, references(:users, @opts), primary_key: true
      add :user_id_2, references(:users, @opts), primary_key: true
      add :score, :integer, null: false
      timestamps()
    end
  end
end
