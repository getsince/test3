defmodule TWeb.MatchView do
  use TWeb, :view
  alias TWeb.FeedView

  def render("match.json", %{id: id} = assigns) do
    inserted_at =
      if naive = assigns[:inserted_at] do
        DateTime.from_naive!(naive, "Etc/UTC")
      end

    %{"id" => id, "profile" => render(FeedView, "feed_profile.json", assigns)}
    |> maybe_put("inserted_at", inserted_at)
    |> maybe_put("expiration_date", assigns[:expiration_date])
  end

  defp maybe_put(map, _k, nil), do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)
end
