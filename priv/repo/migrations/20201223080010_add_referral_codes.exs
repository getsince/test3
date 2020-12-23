defmodule T.Repo.Migrations.AddReferralCodes do
  use Ecto.Migration

  def change do
    create table(:referral_codes, primary_key: false) do
      add :code, :string, primary_key: true
      add :meta, :map
      timestamps(updated_at: false)
    end
  end
end
