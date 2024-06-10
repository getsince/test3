defmodule Since.Repo.Migrations.AddSeenNews do
  use Ecto.Migration

  def change do
    create table(:seen_news, primary_key: false) do
      add :user_id, references(:users, on_delete: :delete_all, type: :uuid), primary_key: true
      add :last_id, :integer
    end
  end
end
