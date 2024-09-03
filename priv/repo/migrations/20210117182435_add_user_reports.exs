defmodule Since.Repo.Migrations.AddUserReports do
  use Ecto.Migration

  @opts [type: :uuid, on_delete: :delete_all]

  def change do
    create table(:user_reports, primary_key: false) do
      add :on_user_id, references(:users, @opts), primary_key: true
      add :from_user_id, references(:users, @opts), primary_key: true
      add :reason, :text, null: false

      timestamps()
    end
  end
end
