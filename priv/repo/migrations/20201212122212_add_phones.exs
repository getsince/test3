defmodule T.Repo.Migrations.AddPhones do
  use Ecto.Migration

  def change do
    create table(:phones, primary_key: false) do
      add :phone_number, :string, null: false
    end
  end
end
