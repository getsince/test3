defmodule T.Repo.Migrations.AddOpenedContactType do
  use Ecto.Migration

  def change do
    alter table(:match_contact) do
      add :opened_contact_type, :string
    end
  end
end
