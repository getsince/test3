defmodule T.Repo.Migrations.AllowMoreMatches do
  use Ecto.Migration

  def change do
    # TODO check constraint count(alive = true) <= 3

    drop index(:matches, [:user_id_1, :alive?],
           where: ~s["alive?" = true],
           unique: true,
           name: "user_id_1_alive_match"
         )

    drop index(:matches, [:user_id_2, :alive?],
           where: ~s["alive?" = true],
           unique: true,
           name: "user_id_2_alive_match"
         )
  end
end
