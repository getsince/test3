defmodule TWeb.FeedView do
  use TWeb, :view
  alias TWeb.{ViewHelpers, CallView}
  alias T.Feeds.{FeedProfile}

  def render("feed_item.json", %{profile: profile, screen_width: screen_width}) do
    profile =
      render_profile(profile, [:user_id, :name, :gender, :story], screen_width, _env = :feed)

    %{"profile" => profile}
  end

  def render("feed_profile.json", %{profile: profile, screen_width: screen_width}) do
    render_profile(profile, [:user_id, :name, :gender, :story], screen_width, _env = :match)
  end

  def render("missed_call.json", %{profile: profile, call: call, screen_width: screen_width}) do
    profile =
      render_profile(profile, [:user_id, :name, :gender, :story], screen_width, _env = :match)

    %{"profile" => profile, "call" => CallView.render("call.json", call: call)}
  end

  def render("news.json", %{news: news, screen_width: screen_width}) do
    Map.update!(news, :story, fn story ->
      ViewHelpers.postprocess_news(story, screen_width)
    end)
  end

  defp render_profile(%FeedProfile{} = profile, fields, screen_width, env) do
    profile
    |> Map.take(fields)
    |> Map.update!(:story, fn story ->
      ViewHelpers.postprocess_story(story, screen_width, env)
    end)
  end
end
