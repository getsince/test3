defmodule T.Repo.Migrations.AddH3 do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add :h3, :bigint
    end
  end
end
