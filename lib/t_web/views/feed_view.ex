defmodule TWeb.FeedView do
  use TWeb, :view
  alias TWeb.{ViewHelpers, CallView}
  alias T.Feeds.{FeedProfile}

  def render("feed_item.json", %{profile: profile, screen_width: screen_width}) do
    %{"profile" => render_profile(profile, [:user_id, :name, :gender, :story], screen_width)}
  end

  def render("feed_profile.json", %{profile: profile, screen_width: screen_width}) do
    render_profile(profile, [:user_id, :name, :gender, :story], screen_width)
  end

  def render("missed_call.json", %{profile: profile, call: call, screen_width: screen_width}) do
    %{
      "profile" => render_profile(profile, [:user_id, :name, :gender, :story], screen_width),
      "call" => CallView.render("call.json", call: call)
    }
  end

  defp render_profile(%FeedProfile{} = profile, fields, screen_width) do
    profile
    |> Map.take(fields)
    |> Map.update!(:story, fn story ->
      ViewHelpers.postprocess_story(story, screen_width)
    end)
  end
end
