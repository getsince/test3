defmodule T.Repo.Migrations.AddMatches do
  use Ecto.Migration

  @opts [on_delete: :delete_all, type: :uuid]

  def change do
    create table(:matches, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id_1, references(:users, @opts), null: false
      add :user_id_2, references(:users, @opts), null: false
      add :alive?, :boolean, default: true, null: false
      # TODO last interaction at?
      timestamps(updated_at: false)
    end

    create index(:matches, [:user_id_1, :alive?],
             where: ~s["alive?" = true],
             unique: true,
             name: "user_id_1_alive_match"
           )

    create index(:matches, [:user_id_2, :alive?],
             where: ~s["alive?" = true],
             unique: true,
             name: "user_id_2_alive_match"
           )
  end
end
