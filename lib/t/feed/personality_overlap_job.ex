defmodule T.Feeds.PersonalityOverlapJob do
  @moduledoc false
  use Oban.Worker, queue: :personality

  import Ecto.Query

  alias T.Repo
  alias T.Accounts.Profile
  alias T.Feeds.PersonalityOverlap

  @impl true
  def perform(%Oban.Job{args: %{"user_id" => my_user_id} = args}) do
    if me = fetch_me(my_user_id) do
      {my_gender, my_tastes} = me

      # TODO join with those who don't have overlap yet
      # TODO don't include deleted, blocked?, hidden?
      other_tastes = fetch_others(my_user_id, my_gender, args)
      overlaps = compute_overlaps(other_tastes, my_user_id, my_tastes)

      {updated, _} =
        Repo.insert_all(PersonalityOverlap, overlaps,
          on_conflict: {:replace, [:score, :updated_at]},
          conflict_target: [:user_id_1, :user_id_2]
        )

      if length(other_tastes) == batch_size(args) do
        {after_id, _tastes} = List.last(other_tastes)

        %{user_id: my_user_id, after_id: after_id}
        |> new(schedule_in: 1)
        |> Oban.insert()
      else
        {:ok, %{updated: updated}}
      end
    else
      {:ok, :no_user}
    end
  end

  @doc false
  def fetch_me(user_id) do
    Profile
    |> where(user_id: ^user_id)
    |> select([p], {p.gender, p.tastes})
    |> Repo.one()
  end

  @doc false
  def fetch_others(my_id, my_gender, args) do
    Profile
    |> where([p], gender: ^opposite_gender(my_gender))
    |> where([p], p.user_id != ^my_id)
    |> maybe_add_after(args["after_id"])
    |> select([p], {p.user_id, p.tastes})
    |> limit(^batch_size(args))
    |> Repo.all()
  end

  defp opposite_gender("F"), do: "M"
  defp opposite_gender("M"), do: "F"

  defp maybe_add_after(query, nil), do: query

  defp maybe_add_after(query, after_id) do
    where(query, [p], p.user_id > ^after_id)
  end

  defp batch_size(args) do
    args["batch_size"] || 50
  end

  @doc false
  def compute_overlaps(other_tastes, my_user_id, my_tastes) do
    Enum.map(other_tastes, fn {other_user_id, other_tastes} ->
      [user_id_1, user_id_2] = Enum.sort([my_user_id, other_user_id])
      timestamp = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

      %{
        user_id_1: user_id_1,
        user_id_2: user_id_2,
        score: calculate_score(my_tastes, other_tastes),
        inserted_at: timestamp,
        updated_at: timestamp
      }
    end)
  end

  @doc false
  def calculate_score(tastes1, tastes2) do
    Enum.reduce(tastes1, 0, fn {k, v1}, score ->
      add =
        if v2 = tastes2[k] do
          # music, tv shows, etc.
          if is_list(v1) and is_list(v2) do
            v1 = MapSet.new(v1)
            v2 = MapSet.new(v2)
            intersection = MapSet.intersection(v1, v2)
            length(MapSet.to_list(intersection))
          else
            # alco / smoking
            if v1 == v2, do: 1
          end
        end || 0

      score + add
    end)
  end
end
