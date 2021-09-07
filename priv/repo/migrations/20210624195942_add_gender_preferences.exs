defmodule T.Repo.Migrations.AddGenderPreferences do
  use Ecto.Migration

  @opts [on_delete: :delete_all, type: :uuid]

  def up do
    create table(:gender_preferences, primary_key: false) do
      add :user_id, references(:users, @opts), primary_key: true
      add :gender, :string, primary_key: true
    end
  end
end
