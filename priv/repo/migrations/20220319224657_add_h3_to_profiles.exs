defmodule T.Repo.Migrations.AddhH3ToProfiles do
  use Ecto.Migration

  import Ecto.Query

  def change do
    alter table(:profiles) do
      add :h3, :bigint
    end

    flush()

    "profiles"
    |> select([p], {p.user_id, p.location})
    |> where([p], not is_nil(p.location))
    |> T.Repo.all()
    |> Enum.chunk_every(300)
    |> Enum.each(fn chunk ->
      updates =
        Enum.map(chunk, fn {user_id, location} ->
          %{coordinates: {lon, lat}} = location
          [user_id: user_id, h3: :h3.from_geo({lat, lon}, 10) - 9_223_372_036_854_775_807]
        end)

      T.Repo.insert_all("profiles", updates,
        on_conflict: {:replace, [:h3]},
        conflict_target: :user_id
      )
    end)
  end
end
