defmodule T.Repo.Migrations.AddTimesShownAndLikeRatio do
  use Ecto.Migration

  import Ecto.Query

  def change do
    alter table(:profiles) do
      add :times_shown, :integer, null: false, default: 0
      add :like_ratio, :float, null: false, default: 0
    end

    drop index(:profiles, [:times_liked])
    create index(:profiles, [:like_ratio])

    flush()

    T.Feeds.FeedProfile
    |> update(set: [times_liked: 0])
    |> T.Repo.update_all([])
  end
end
