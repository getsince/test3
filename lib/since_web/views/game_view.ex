defmodule SinceWeb.GameView do
  use SinceWeb, :view
  alias SinceWeb.FeedView
  alias Since.Games

  def render("game.json", %{game: game, version: version, screen_width: screen_width}) do
    %{"prompt" => prompt, "profiles" => profiles} = game

    %{
      "prompt" => render_prompt(prompt),
      "profiles" => profiles |> Enum.map(fn p -> render_profile(p, version, screen_width) end)
    }
  end

  def render("compliment.json", %{
        id: id,
        prompt: prompt,
        profile: profile,
        seen: seen,
        inserted_at: inserted_at,
        version: version,
        screen_width: screen_width
      }) do
    %{
      "id" => id,
      "prompt" => prompt,
      "text" => Games.render(prompt),
      "push_text" => push_text(prompt, profile),
      "emoji" => Games.prompts()[prompt] || "❤️",
      "seen" => seen,
      "inserted_at" => ensure_utc(inserted_at)
    }
    |> maybe_put_profile(profile, version, screen_width)
  end

  defp push_text(prompt, nil = _profile),
    do: Games.render(prompt <> "_push_M")

  defp push_text(prompt, profile),
    do: Games.render(prompt <> "_push_" <> profile.gender)

  defp render_prompt({emoji, tag, text}), do: %{"emoji" => emoji, "tag" => tag, "text" => text}

  defp render_profile(profile, version, screen_width) do
    render(FeedView, "feed_profile.json", %{
      profile: profile,
      version: version,
      screen_width: screen_width
    })
  end

  defp maybe_put_profile(map, nil, _version, _screen_width), do: map

  defp maybe_put_profile(map, profile, version, screen_width),
    do: map |> Map.put("profile", render_profile(profile, version, screen_width))

  defp ensure_utc(%DateTime{} = datetime), do: datetime
  defp ensure_utc(%NaiveDateTime{} = naive), do: DateTime.from_naive!(naive, "Etc/UTC")
  defp ensure_utc(nil), do: nil
end
