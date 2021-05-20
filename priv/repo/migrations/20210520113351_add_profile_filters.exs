defmodule T.Repo.Migrations.AddProfileFilters do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add :filters, :jsonb, default: "{}"
    end
  end
end
