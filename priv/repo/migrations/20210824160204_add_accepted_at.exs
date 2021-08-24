defmodule T.Repo.Migrations.AddAcceptedAt do
  use Ecto.Migration

  def change do
    alter table(:calls) do
      add :accepted_at, :timestamptz
    end
  end
end
