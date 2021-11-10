defmodule T.Repo.Migrations.AddAgeAndDistancePreferences do
  use Ecto.Migration

  @opts [on_delete: :delete_all, type: :uuid]

  def up do
    create table(:min_age_preferences, primary_key: false) do
      add :user_id, references(:users, @opts), primary_key: true
      add :age, :integer, null: false
    end

    create table(:max_age_preferences, primary_key: false) do
      add :user_id, references(:users, @opts), primary_key: true
      add :age, :integer, null: false
    end

    create table(:distance_preferences, primary_key: false) do
      add :user_id, references(:users, @opts), primary_key: true
      add :distance, :integer, null: false
    end
  end
end
