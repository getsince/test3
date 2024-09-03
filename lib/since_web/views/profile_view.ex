defmodule SinceWeb.ProfileView do
  use SinceWeb, :view
  alias SinceWeb.ViewHelpers

  alias Since.Accounts.Profile

  def render("show_with_location.json", %{
        profile: %Profile{location: location} = profile,
        screen_width: screen_width,
        version: version
      }) do
    profile
    |> render_profile(
      [
        :user_id,
        :name,
        :gender,
        :birthdate,
        :gender_preference,
        :min_age,
        :max_age,
        :distance,
        :address,
        :premium
      ],
      version,
      screen_width,
      _env = :profile
    )
    |> Map.put(:latitude, lat(location))
    |> Map.put(:longitude, lon(location))
  end

  defp lat(%Geo.Point{coordinates: {_lon, lat}}), do: lat
  defp lat(nil), do: nil

  defp lon(%Geo.Point{coordinates: {lon, _lat}}), do: lon
  defp lon(nil), do: nil

  defp render_profile(%Profile{story: story} = profile, fields, version, screen_width, env) do
    profile
    |> Map.take(fields)
    |> Map.merge(%{story: ViewHelpers.postprocess_story(story || [], version, screen_width, env)})
  end
end
