defmodule TWeb.FeedView do
  use TWeb, :view
  alias TWeb.ViewHelpers
  alias T.Feeds.{FeedProfile, ActiveSession}

  def render("feed_profile.json", %{profile: profile, screen_width: screen_width}) do
    render_profile(profile, [:user_id, :song, :name, :story], screen_width)
  end

  def render("feed_item.json", %{profile: profile, session: session, screen_width: screen_width}) do
    %{
      profile: render_profile(profile, [:user_id, :song, :name, :story], screen_width),
      session: render_session(session)
    }
  end

  def render("session.json", %{session: session}) do
    render_session(session)
  end

  defp render_session(%ActiveSession{flake: flake, expires_at: expires_at}) do
    %{id: flake, expires_at: expires_at}
  end

  defp render_profile(%FeedProfile{} = profile, fields, screen_width) do
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
