defmodule T.Repo.Migrations.AddProfileStory do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      # TODO null: false?
      add :story, :jsonb
    end
  end
end
