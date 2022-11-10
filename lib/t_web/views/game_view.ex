defmodule TWeb.GameView do
  use TWeb, :view
  alias TWeb.FeedView
  alias T.Games.Compliment

  def render("game.json", %{game: game, version: version, screen_width: screen_width}) do
    %{"prompt" => prompt, "profiles" => profiles} = game

    %{
      "prompt" => render_prompt(prompt),
      "profiles" => profiles |> Enum.map(fn p -> render_profile(p, version, screen_width) end)
    }
  end

  def render("compliment.json", %Compliment{
        id: id,
        prompt: prompt,
        text: text,
        seen: seen,
        inserted_at: inserted_at
      }) do
    %{
      "id" => id,
      "prompt" => prompt,
      "text" => text,
      "seen" => seen,
      "inserted_at" => inserted_at
    }
  end

  defp render_prompt({emoji, tag, text}), do: %{"emoji" => emoji, "tag" => tag, "text" => text}

  defp render_profile(profile, version, screen_width) do
    render(FeedView, "feed_profile_with_distance.json", %{
      profile: profile,
      version: version,
      screen_width: screen_width
    })
  end
end
