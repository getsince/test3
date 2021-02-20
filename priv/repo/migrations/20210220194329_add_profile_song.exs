defmodule T.Repo.Migrations.AddProfileSong do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add :song, :jsonb
      remove :audio_preview_url, :string
    end
  end
end
