defmodule T.Repo.Migrations.AddUsersOnboardedWithStoryAt do
  use Ecto.Migration
  import Ecto.Query

  def change do
    alter table(:users) do
      add :onboarded_with_story_at, :utc_datetime
    end

    flush()

    "users"
    |> join(:inner, [u], p in "profiles", on: p.user_id == u.id and not p.hidden?)
    |> update([u], set: [onboarded_with_story_at: u.onboarded_at])
    |> T.Repo.update_all([])
  end
end
