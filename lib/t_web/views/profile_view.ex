defmodule TWeb.ProfileView do
  use TWeb, :view
  alias T.Accounts.User

  def render("show.json", %{profile: %User.Profile{} = profile}) do
    Map.take(profile, [
      :photos,
      :name,
      :gender,
      :birthdate,
      :height,
      :home_city,
      :occupation,
      :job,
      :university,
      :major,
      :most_important_in_life,
      :interests,
      :first_date_idea,
      :free_form,
      :music,
      :sports,
      :alcohol,
      :smoking,
      :books,
      :currently_studying,
      :tv_shows,
      :languages,
      :musical_instruments,
      :movies,
      :social_networks,
      :cuisines,
      :pets
    ])
  end
end
