defmodule TWeb.MeController do
  use TWeb, :controller
  alias T.{Accounts, Media}
  alias T.Accounts.User

  # TODO params
  def me(conn, _params) do
    current_user = conn.assigns.current_user

    json(conn, %{
      me: current_user.id,
      next: next(current_user),
      token: Phoenix.Token.sign(conn, "Urm6JRcI", current_user.id)
    })
  end

  defp next(user) do
    cond do
      blocked?(user) -> "blocked"
      not onboarded?(user) -> "onboarding"
      true -> "main"
    end
  end

  defp blocked?(%User{blocked_at: blocked_at}) do
    not is_nil(blocked_at)
  end

  defp onboarded?(%User{onboarded_at: onboarded_at}) do
    not is_nil(onboarded_at)
  end

  def profile(conn, _params) do
    current_user = conn.assigns.current_user

    %User{
      profile:
        %User.Profile{
          name: name,
          gender: gender,
          birthdate: birthdate,
          height: height,
          home_city: home_city,
          occupation: occupation,
          job: job,
          university: university,
          major: major,
          most_important_in_life: most_important_in_life,
          interests: interests,
          first_date_idea: first_date_idea,
          free_form: free_form,
          music: music,
          sports: sports,
          cuisines: cuisines,
          social_networks: social_networks,
          movies: movies,
          musical_instruments: musical_instruments,
          languages: languages,
          tv_shows: tv_shows,
          currently_studying: currently_studying,
          books: books,
          smoking: smoking,
          alcohol: alcohol,
          pets: pets
        } = profile
    } = Accounts.ensure_profile(current_user)

    json(conn, %{
      profile: %{
        photos:
          Enum.map(profile.photos, fn key ->
            %{key: key, url: Media.presigned_url(key)}
          end),
        name: name,
        gender: gender,
        birthdate: birthdate,
        height: height,
        home_city: home_city,
        occupation: occupation,
        job: job,
        university: university,
        major: major,
        most_important_in_life: most_important_in_life,
        interests: interests,
        first_date_idea: first_date_idea,
        free_form: free_form,
        music: music,
        sports: sports,
        cuisines: cuisines,
        social_networks: social_networks,
        movies: movies,
        musical_instruments: musical_instruments,
        languages: languages,
        tv_shows: tv_shows,
        currently_studying: currently_studying,
        books: books,
        smoking: smoking,
        alcohol: alcohol,
        pets: pets
      }
    })
  end
end
