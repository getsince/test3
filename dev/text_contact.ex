defmodule Dev.TextContact do
  import Ecto.Query
  alias T.{Repo, Accounts.Profile}

  def impacted_user_ids do
    %Postgrex.Result{columns: ["user_id"], rows: rows} =
      Repo.query!("""
      SELECT DISTINCT user_id
      FROM (SELECT user_id, jsonb_array_elements(jsonb_array_elements(story) -> 'labels') AS label FROM profiles) AS l
      WHERE (l.label ->> 'text-contact') = 'true'
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
      %{profile | story: fix_story(story)}
    end)
  end

  def fix_story(nil), do: nil

  def fix_story(story) when is_list(story) do
    Enum.map(story, fn
      %{"labels" => labels} = page ->
        labels =
          labels
          |> Enum.reduce([], fn label, acc ->
            case label do
              %{"text-contact" => _} -> acc
              label -> [label | acc]
            end
          end)
          |> :lists.reverse()

        %{page | "labels" => labels}

      page ->
        page
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
