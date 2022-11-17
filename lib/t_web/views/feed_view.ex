defmodule TWeb.FeedView do
  use TWeb, :view
  alias TWeb.ViewHelpers
  alias T.Feeds.{FeedProfile, Meeting}

  def render("feed_item.json", %{profile: profile, version: version, screen_width: screen_width}) do
    profile =
      render_profile(
        profile,
        [:user_id, :name, :gender, :story, :distance, :address],
        version,
        screen_width,
        _env = :feed
      )

    %{"profile" => profile}
  end

  def render("feed_profile.json", %{
        profile: profile,
        version: version,
        screen_width: screen_width
      }) do
    render_profile(
      profile,
      [:user_id, :name, :gender, :story, :distance, :address],
      version,
      screen_width,
      _env = :feed
    )
  end

  def render("match_profile.json", %{
        profile: profile,
        version: version,
        screen_width: screen_width
      }) do
    render_profile(
      profile,
      [:user_id, :name, :gender, :story, :distance, :address],
      version,
      screen_width,
      _env = :match
    )
  end

  def render("meeting.json", %{meeting: meeting, version: version, screen_width: screen_width}) do
    %Meeting{
      id: id,
      user_id: user_id,
      data: data,
      profile: profile,
      inserted_at: inserted_at
    } = meeting

    %{
      "id" => id,
      "user_id" => user_id,
      "data" => data,
      "inserted_at" => inserted_at,
      "profile" =>
        render_profile(
          profile,
          [:user_id, :name, :gender, :story, :distance, :address],
          version,
          screen_width,
          _env = :feed
        )
    }
  end

  defp render_profile(%FeedProfile{} = profile, fields, version, screen_width, env) do
    profile
    |> Map.take(fields)
    |> Map.update!(:story, fn story ->
      ViewHelpers.postprocess_story(story, version, screen_width, env)
    end)
  end
end
