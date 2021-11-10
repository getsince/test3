defmodule TWeb.ProfileView do
  use TWeb, :view
  alias TWeb.ViewHelpers

  alias T.Accounts.{
    Profile,
    GenderPreference,
    MinAgePreference,
    MaxAgePreference,
    DistancePreference
  }

  def render("show.json", %{profile: %Profile{} = profile, screen_width: screen_width}) do
    render_profile(profile, [:user_id, :name, :gender], screen_width)
  end

  def render("show_with_location.json", %{
        profile:
          %Profile{
            location: location,
            gender_preference: gender_preference,
            min_age_preference: min_age_preference,
            max_age_preference: max_age_preference,
            distance_preference: distance_preference
          } = profile,
        screen_width: screen_width
      }) do
    profile
    |> render_profile([:user_id, :name, :gender, :birthdate], screen_width)
    |> Map.put(:latitude, lat(location))
    |> Map.put(:longitude, lon(location))
    |> maybe_put_gender_preference(gender_preference)
    |> maybe_put_min_age_preference(min_age_preference)
    |> maybe_put_max_age_preference(max_age_preference)
    |> maybe_put_distance_preference(distance_preference)
  end

  def render("editor_tutorial_story.json", %{story: story, screen_width: screen_width}) do
    ViewHelpers.postprocess_story(story, screen_width)
  end

  defp lat(%Geo.Point{coordinates: {_lon, lat}}), do: lat
  defp lat(nil), do: nil

  defp lon(%Geo.Point{coordinates: {lon, _lat}}), do: lon
  defp lon(nil), do: nil

  defp maybe_put_gender_preference(profile, nil) do
    profile |> Map.put(:gender_preference, nil)
  end

  defp maybe_put_gender_preference(profile, gender_preference) do
    profile
    |> Map.put(
      :gender_preference,
      Enum.map(gender_preference, fn %GenderPreference{gender: gender} ->
        gender
      end)
    )
  end

  defp maybe_put_min_age_preference(profile, nil) do
    profile |> Map.put(:min_age, nil)
  end

  defp maybe_put_min_age_preference(profile, %MinAgePreference{age: min_age}) do
    profile |> Map.put(:min_age, min_age)
  end

  defp maybe_put_max_age_preference(profile, nil) do
    profile |> Map.put(:max_age, nil)
  end

  defp maybe_put_max_age_preference(profile, %MaxAgePreference{age: max_age}) do
    profile |> Map.put(:max_age, max_age)
  end

  defp maybe_put_distance_preference(profile, nil) do
    profile |> Map.put(:distance, nil)
  end

  defp maybe_put_distance_preference(profile, %DistancePreference{distance: distance}) do
    profile |> Map.put(:distance, distance)
  end

  defp render_profile(%Profile{story: story} = profile, fields, screen_width) do
    profile
    |> Map.take(fields)
    |> Map.merge(%{story: ViewHelpers.postprocess_story(story || [], screen_width)})
  end
end
