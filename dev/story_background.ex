defmodule Dev.StoryBackground do
  import Ecto.Query
  alias T.{Repo, StoryBackground, Accounts.Profile}

  def impacted_user_ids do
    %Postgrex.Result{columns: ["user_id"], rows: rows} =
      Repo.query!("""
      SELECT DISTINCT user_id
      FROM (SELECT user_id, jsonb_array_elements(story) -> 'background' AS background FROM profiles) AS b
      WHERE (b.background ->> 'proxy') is not null
      """)

    Enum.map(rows, fn [user_id] -> Ecto.UUID.cast!(user_id) end)
  end

  defp fetch_profiles(user_ids) do
    Profile
    |> where([p], p.user_id in ^user_ids)
    |> select([p], map(p, [:user_id, :story]))
    |> Repo.all()
  end

  defp fix_profiles(profiles) do
    Enum.map(profiles, fn %{story: story} = profile ->
      %{profile | story: StoryBackground.fix_story(story)}
    end)
  end

  def run do
    impacted_user_ids()
    |> Enum.chunk_every(20)
    |> Enum.reduce(0, fn user_ids, total_count ->
      profiles = user_ids |> fetch_profiles() |> fix_profiles()

      {count, _} =
        Repo.insert_all(Profile, profiles,
          on_conflict: {:replace, [:story]},
          conflict_target: :user_id
        )

      total_count = total_count + count
      IO.puts("updated #{count} profiles, total: #{total_count}")
      total_count
    end)
  end
end
