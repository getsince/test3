defmodule T.Repo.Migrations.AddMatchVoicemail do
  use Ecto.Migration

  def change do
    create table(:match_voicemail, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :caller_id,
          references(:profiles, on_delete: :delete_all, type: :uuid, column: :user_id),
          null: false

      add :match_id,
          references(:matches, on_delete: :delete_all, type: :uuid, column: :id),
          null: false

      add :s3_key, :string
      timestamps(updated_at: false)
    end

    create index(:match_voicemail, [:match_id])
  end
end
