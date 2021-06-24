defmodule T.Repo.Migrations.TurnProfileFeedsIntoJoinTable do
  use Ecto.Migration

  def up do
    drop table(:profile_feeds)

    create table(:profile_feeds, primary_key: false) do
      add :user_id, references(:users, on_delete: :delete_all, type: :uuid), primary_key: true
      add :feeded_id, references(:users, on_delete: :delete_all, type: :uuid), primary_key: true
    end
  end
end
