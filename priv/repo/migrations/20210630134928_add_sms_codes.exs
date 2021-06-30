defmodule T.Repo.Migrations.AddSmsCodes do
  use Ecto.Migration

  def change do
    create table(:sms_codes, primary_key: false) do
      add :phone_number, :string, primary_key: true
      add :code, :string, null: false
      add :attempts, :integer, default: 0, null: false

      timestamps(updated_at: false)
    end
  end
end
