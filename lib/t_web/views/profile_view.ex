defmodule TWeb.ProfileView do
  use TWeb, :view
  alias T.Accounts.Profile

  def render("show.json", %{profile: %Profile{} = profile}) do
    Map.take(profile, [
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
  end
end
