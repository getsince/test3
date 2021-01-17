defmodule T.Repo.Migrations.AddUserReports do
  use Ecto.Migration

  def change do
    create table(:user_reports, primary_key: false) do
      add :on_user_id, references(:users, type: :uuid, on_delete: :delete_all), primary_key: true

      add :from_user_id, references(:users, type: :uuid, on_delete: :delete_all),
        primary_key: true

      add :reason, :text, null: false

      timestamps()
    end
  end
end
