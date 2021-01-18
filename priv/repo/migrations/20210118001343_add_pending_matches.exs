defmodule T.Repo.Migrations.AddPendingMatches do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :pending?, :boolean
    end

    create index(:matches, [:user_id_1, :pending?], where: ~s["pending?" = true])
    create index(:matches, [:user_id_2, :pending?], where: ~s["pending?" = true])
  end
end
