defmodule T.Repo.Migrations.AddMatches do
  use Ecto.Migration

  def change do
    # create table(:matches, primary_key: false) do
    #   add :id, :uuid, primary_key: true
    #   add :user_id_1, references(:users)
    #   add :user_id_2, references(:users)
    #   # TODO last interaction at?
    #   timestamp(updated_at: false)
    # end
  end
end
