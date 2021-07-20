defmodule TWeb.FeedView do
  use TWeb, :view
  alias TWeb.ViewHelpers
  alias T.Feeds.FeedProfile

  def render("feed_item.json", %{
        profile: %FeedProfile{} = profile,
        expires_at: expires_at,
        screen_width: screen_width
      }) do
    %{
      profile: render_profile(profile, [:user_id, :song, :name, :story], screen_width),
      expires_at: expires_at
    }
  end

  defp render_profile(profile, fields, screen_width) do
    profile
    |> Map.take(fields)
    |> Map.update!(:song, fn song ->
      if song, do: ViewHelpers.extract_song_info(song)
    end)
    |> Map.update!(:story, fn story ->
      ViewHelpers.postprocess_story(story, screen_width)
    end)
  end
end
