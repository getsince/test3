defmodule TWeb.AudioLive.PickUser do
  use TWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket = assign(socket, user_options: all_user_options())
    {:ok, socket}
  end

  @impl true
  def handle_event("submit", %{"user" => user_id}, socket) do
    path = Routes.audio_path(socket, :pick_match, user_id)
    {:noreply, push_redirect(socket, to: path)}
  end

  defp all_user_options do
    import Ecto.Query

    T.Accounts.Profile
    |> Ecto.Query.select([p], {p.name, p.user_id})
    |> order_by([p], desc: p.times_liked)
    |> T.Repo.all()
  end
end
