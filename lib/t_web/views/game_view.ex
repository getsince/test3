defmodule TWeb.GameView do
  use TWeb, :view
  alias TWeb.FeedView

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
        text: text,
        emoji: emoji,
        push_text: push_text,
        seen: seen,
        inserted_at: inserted_at
      }) do
    %{
      "id" => id,
      "prompt" => prompt,
      "text" => text,
      "push_text" => push_text,
      "emoji" => emoji,
      "seen" => seen,
      "inserted_at" => ensure_utc(inserted_at)
    }
  end

  defp render_prompt({emoji, tag, text}), do: %{"emoji" => emoji, "tag" => tag, "text" => text}

  defp render_profile(profile, version, screen_width) do
    render(FeedView, "feed_profile.json", %{
      profile: profile,
      version: version,
      screen_width: screen_width
    })
  end

  defp ensure_utc(%DateTime{} = datetime), do: datetime
  defp ensure_utc(%NaiveDateTime{} = naive), do: DateTime.from_naive!(naive, "Etc/UTC")
  defp ensure_utc(nil), do: nil
end
