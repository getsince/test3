defmodule SinceWeb.ProfileView do
  use SinceWeb, :view
  alias SinceWeb.ViewHelpers

  alias Since.Accounts.Profile

  def render("show_with_location.json", %{
        profile: %Profile{h3: h3} = profile,
        screen_width: screen_width,
        version: version
      }) do
    {lat, lon} = if h3, do: :h3.to_geo(h3), else: {nil, nil}

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
    |> Map.put(:latitude, lat && Float.round(lat, 5))
    |> Map.put(:longitude, lon && Float.round(lon, 5))
  end

  defp render_profile(%Profile{story: story} = profile, fields, version, screen_width, env) do
    profile
    |> Map.take(fields)
    |> Map.merge(%{story: ViewHelpers.postprocess_story(story || [], version, screen_width, env)})
  end
end
