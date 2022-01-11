defmodule T.Repo.Migrations.AddMatchExchangedVoicemail do
  use Ecto.Migration
  alias T.Repo

  def change do
    alter table(:matches) do
      add :exchanged_voicemail, :boolean, default: false, null: false
    end

    flush()

    # to stop matches in between two and seven days from expiring
    Repo.update_all("matches", set: [exchanged_voicemail: true])
  end
end
