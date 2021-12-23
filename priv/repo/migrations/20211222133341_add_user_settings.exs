defmodule T.Repo.Migrations.AddUserSettings do
  use Ecto.Migration
  import Ecto.Query

  @opts [type: :uuid, on_delete: :delete_all]

  def change do
    create table(:user_settings, primary_key: false) do
      add :user_id, references(:users, @opts), primary_key: true
      add :audio_only, :boolean, null: false
    end

    flush()

    user_settings =
      "users"
      |> select([u], u.id)
      |> T.Repo.all()
      |> Enum.map(fn id ->
        %{
          user_id: id,
          audio_only: false
        }
      end)

    T.Repo.insert_all("user_settings", user_settings)
  end
end
