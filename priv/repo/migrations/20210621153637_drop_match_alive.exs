defmodule T.Repo.Migrations.DropMatchAlive do
  use Ecto.Migration
  import Ecto.Query

  def up do
    "matches" |> where([m], alive?: false) |> T.Repo.delete_all()

    alter table(:matches) do
      remove :alive?
    end
  end
end
