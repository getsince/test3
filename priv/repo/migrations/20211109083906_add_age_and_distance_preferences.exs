defmodule T.Repo.Migrations.AddAgeAndDistancePreferences do
  use Ecto.Migration

  @opts [on_delete: :delete_all, type: :uuid]

  def up do
    create table(:age_preferences, primary_key: false) do
      add(:user_id, references(:users, @opts), primary_key: true)
      add(:min_age, :integer, null: true, default: nil)
      add(:max_age, :integer, null: true, default: nil)
    end

    create table(:distance_preferences, primary_key: false) do
      add(:user_id, references(:users, @opts), primary_key: true)
      add(:distance, :integer, null: true, default: nil)
    end
  end
end
