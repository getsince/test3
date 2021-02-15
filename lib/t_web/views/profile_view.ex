defmodule TWeb.ProfileView do
  use TWeb, :view
  alias T.Accounts.Profile
  alias T.Media

  def render("show.json", %{profile: %Profile{} = profile}) do
    profile
    |> Map.take([
      :user_id,
      :photos,
      :audio_preview_url,
      :name,
      :gender,
      :birthdate,
      :height,
      :city,
      :occupation,
      :job,
      :university,
      :major,
      :most_important_in_life,
      :interests,
      :first_date_idea,
      :free_form,
      :tastes
    ])
    |> Map.update!(:photos, fn photos ->
      (photos || [])
      |> Enum.reject(&is_nil/1)
      |> Enum.map(fn key -> %{"s3" => Media.s3_url(key), "proxy" => Media.imgproxy_url(key)} end)
    end)
  end
end
