defmodule T.Repo.Migrations.AddhH3ToProfiles do
  use Ecto.Migration

  import Ecto.Query
  import Ecto.Changeset
  alias T.Feeds.FeedProfile

  def change do
    alter table(:profiles) do
      add :h3, :decimal
    end

    flush()

    FeedProfile
    |> T.Repo.all()
    |> Enum.each(fn profile ->
      if profile.location do
        h3 = :h3.from_geo(profile.location.coordinates, 10)

        profile
        |> cast(%{h3: h3}, [:h3])
        |> T.Repo.update!()
      end
    end)
  end
end
