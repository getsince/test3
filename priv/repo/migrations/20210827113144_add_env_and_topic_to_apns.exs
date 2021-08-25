defmodule T.Repo.Migrations.AddEnvAndTopicToApns do
  use Ecto.Migration

  def change do
    alter table(:apns_devices) do
      add :topic, :string
      add :env, :string
    end

    alter table(:pushkit_devices) do
      add :topic, :string
      add :env, :string
    end
  end
end
