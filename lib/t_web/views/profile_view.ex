defmodule TWeb.ProfileView do
  use TWeb, :view
  alias T.Accounts.Profile
  alias T.Media

  def render("show.json", %{profile: %Profile{} = profile}) do
    profile
    |> Map.take([
      :user_id,
      :photos,
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
      Enum.map(photos, fn key -> Media.url(key) end)
    end)
  end
end
