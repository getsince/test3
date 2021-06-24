defmodule T.Repo.Migrations.AddGenderPreferences do
  use Ecto.Migration
  import Ecto.Query

  def up do
    create table(:gender_preferences, primary_key: false) do
      # TODO reference profiles table?
      add :user_id, references(:users, on_delete: :delete_all, type: :uuid), primary_key: true
      add :gender, :string, primary_key: true
    end

    flush()

    preferences =
      "profiles"
      |> select([p], {p.user_id, json_extract_path(p.filters, ["genders"])})
      |> T.Repo.all()
      |> Enum.filter(fn {_user_id, gender_preferences} -> gender_preferences end)
      |> Enum.flat_map(fn {user_id, gender_preferences} when is_list(gender_preferences) ->
        Enum.map(gender_preferences, fn p -> %{user_id: user_id, gender: p} end)
      end)

    T.Repo.insert_all("gender_preferences", preferences)
  end
end
