defmodule T.Repo.Migrations.AddAudioPreviewUrlProfile do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add :audio_preview_url, :string
    end
  end
end
