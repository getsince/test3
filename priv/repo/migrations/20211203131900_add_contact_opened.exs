defmodule T.Repo.Migrations.AddContactOpened do
  use Ecto.Migration

  def change do
    alter table(:match_contact) do
      add :opened, :boolean
    end
  end
end
