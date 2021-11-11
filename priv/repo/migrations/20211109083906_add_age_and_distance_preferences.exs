defmodule T.Repo.Migrations.AddAgeAndDistancePreferences do
  use Ecto.Migration

  import Ecto.Query

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

    flush()

    user_ids = "users" |> select([u], u.id) |> T.Repo.all()

    T.Repo.insert_all(
      "min_age_preferences",
      user_ids |> Enum.map(fn id -> %{user_id: id, age: 18} end)
    )

    T.Repo.insert_all(
      "max_age_preferences",
      user_ids |> Enum.map(fn id -> %{user_id: id, age: 100} end)
    )

    T.Repo.insert_all(
      "distance_preferences",
      user_ids |> Enum.map(fn id -> %{user_id: id, distance: 20000} end)
    )
  end
end
