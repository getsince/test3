defmodule T.Repo.Migrations.MatchMessages do
  use Ecto.Migration

  @opts [type: :uuid, on_delete: :delete_all]

  def change do
    create table(:match_messages, primary_key: false) do
      add :match_id, references(:matches, @opts), primary_key: true
      # add :timestamp, :utc_datetime, null: false
      add :id, :uuid, primary_key: true
      add :author_id, references(:users, @opts), null: false
      add :kind, :string, null: false
      add :data, :jsonb, null: false
      timestamps(updated_at: false)
    end
  end
end
