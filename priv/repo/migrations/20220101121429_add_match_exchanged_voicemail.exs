defmodule T.Repo.Migrations.AddMatchExchangedVoicemail do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :exchanged_voicemail, :boolean, default: false, null: false
    end
  end
end
