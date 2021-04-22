defmodule TWeb.ProfileController do
  use TWeb, :controller
  alias T.Accounts
  alias T.Accounts.Profile

  # TODO test
  def update(conn, %{"profile" => params}) do
    user = conn.assigns.current_user
    %Profile{} = profile = Accounts.get_profile!(user)

    f =
      if Accounts.user_onboarded?(user.id) do
        fn -> Accounts.update_profile(profile, params) end
      else
        fn -> Accounts.onboard_profile(profile, params) end
      end

    case f.() do
      {:ok, profile} ->
        render(conn, "show.json", profile: profile)

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(422)
        |> put_view(TWeb.SpecialView)
        |> render("changeset.json", changeset: changeset)
    end
  end
end
