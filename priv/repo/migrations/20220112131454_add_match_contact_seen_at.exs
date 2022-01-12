defmodule T.Repo.Migrations.AddMatchContactSeenAt do
  use Ecto.Migration

  def change do
    alter table(:match_contact) do
      add :seen_at, :utc_datetime
    end
  end
end
