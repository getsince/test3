defmodule TWeb.ProfileView do
  use TWeb, :view
  alias TWeb.ViewHelpers
  alias T.Accounts.Profile

  def render("show.json", %{profile: %Profile{} = profile, screen_width: screen_width}) do
    render_profile(profile, [:user_id, :name, :gender], screen_width)
  end

  def render("show_with_location.json", %{
        profile: %Profile{location: location, filters: filters} = profile,
        screen_width: screen_width
      }) do
    profile
    |> render_profile([:user_id, :name, :gender, :birthdate], screen_width)
    |> Map.put(:latitude, lat(location))
    |> Map.put(:longitude, lon(location))
    |> Map.put(:gender_preference, genders(filters))
  end

  def render("editor_tutorial_story.json", %{story: story, screen_width: screen_width}) do
    ViewHelpers.postprocess_story(story, screen_width)
  end

  defp lat(%Geo.Point{coordinates: {_lon, lat}}), do: lat
  defp lat(nil), do: nil

  defp lon(%Geo.Point{coordinates: {lon, _lat}}), do: lon
  defp lon(nil), do: nil

  defp genders(%Profile.Filters{genders: genders}), do: genders
  defp genders(nil), do: nil

  defp render_profile(%Profile{story: story} = profile, fields, screen_width) do
    profile
    |> Map.take(fields)
    |> Map.merge(%{story: ViewHelpers.postprocess_story(story || [], screen_width)})
  end
end
