defmodule T.Repo.Migrations.AddEmails do
  use Ecto.Migration

  def change do
    create table(:emails, primary_key: false) do
      add :email, :string, null: false
    end
  end
end
