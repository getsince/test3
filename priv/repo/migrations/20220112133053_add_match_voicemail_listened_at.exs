defmodule T.Repo.Migrations.AddMatchVoicemailListenedAt do
  use Ecto.Migration

  def change do
    alter table(:match_voicemail) do
      add :listened_at, :utc_datetime
    end
  end
end
