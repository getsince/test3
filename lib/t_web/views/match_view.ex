defmodule TWeb.MatchView do
  use TWeb, :view
  alias TWeb.FeedView

  def render("match.json", %{id: id} = assigns) do
    inserted_at = ensure_utc(assigns[:inserted_at])
    expiration_date = ensure_utc(assigns[:expiration_date])

    %{"id" => id, "profile" => render(FeedView, "feed_profile.json", assigns)}
    |> maybe_put("inserted_at", inserted_at)
    |> maybe_put("expiration_date", expiration_date)
    |> maybe_put_2("seen", assigns[:seen])
  end

  defp maybe_put(map, _k, nil), do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)

  defp maybe_put_2(map, _k, nil), do: map
  defp maybe_put_2(map, _k, false), do: map
  defp maybe_put_2(map, k, v), do: Map.put(map, k, v)

  defp ensure_utc(%DateTime{} = datetime), do: datetime
  defp ensure_utc(%NaiveDateTime{} = naive), do: DateTime.from_naive!(naive, "Etc/UTC")
  defp ensure_utc(nil), do: nil
end
