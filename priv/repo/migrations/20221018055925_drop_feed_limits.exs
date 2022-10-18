defmodule T.Repo.Migrations.DropFeedLimits do
  use Ecto.Migration

  def change do
    drop table(:feed_limits)
  end
end
