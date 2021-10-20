defmodule T.Repo.Migrations.AddTimesLikedToFeedProfiles do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add :times_liked, :integer, null: false, default: 0
    end
  end
end
