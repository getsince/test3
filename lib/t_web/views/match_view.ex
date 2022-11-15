defmodule TWeb.MatchView do
  use TWeb, :view
  alias TWeb.{FeedView, ViewHelpers}
  alias T.Matches.Interaction

  def render("match.json", %{id: id} = assigns) do
    %{"id" => id, "profile" => render(FeedView, "match_profile.json", assigns)}
    |> maybe_put("inserted_at", ensure_utc(assigns[:inserted_at]))
    |> maybe_put("expiration_date", ensure_utc(assigns[:expiration_date]))
    |> maybe_put("seen", assigns[:seen])
    |> render_interactions(assigns[:interactions])
  end

  def render("interaction.json", %{interaction: interaction}) do
    %Interaction{
      id: id,
      from_user_id: from_user_id,
      data: %{"sticker" => sticker, "size" => [width, _height] = size},
      seen: seen
    } = interaction

    %{
      "id" => id,
      "interaction" => %{
        "sticker" => ViewHelpers.process_sticker(sticker, width),
        "size" => size
      },
      "inserted_at" => datetime(id),
      "from_user_id" => from_user_id,
      "seen" => seen
    }
  end

  defp render_interactions(map, interactions) when is_list(interactions) do
    Map.put(
      map,
      "interactions",
      interactions
      |> Enum.map(fn interaction -> render("interaction.json", %{interaction: interaction}) end)
    )
  end

  defp render_interactions(map, _interactions), do: map

  defp datetime(<<_::288>> = uuid) do
    datetime(Ecto.Bigflake.UUID.dump!(uuid))
  end

  defp datetime(<<unix::64, _rest::64>>) do
    unix |> DateTime.from_unix!(:millisecond) |> DateTime.truncate(:second)
  end

  defp maybe_put(map, _k, nil), do: map
  defp maybe_put(map, _k, false), do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)

  defp ensure_utc(%DateTime{} = datetime), do: datetime
  defp ensure_utc(%NaiveDateTime{} = naive), do: DateTime.from_naive!(naive, "Etc/UTC")
  defp ensure_utc(nil), do: nil
end
