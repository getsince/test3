defmodule TWeb.AudioLive.PickMatch do
  use TWeb, :live_view

  @impl true
  def mount(%{"user_id" => user_id}, _session, socket) do
    user = T.Accounts.get_user!(user_id)
    socket = assign(socket, user: user, user_options: all_other_user_options(user))
    {:ok, socket}
  end

  @impl true
  def handle_event("submit", %{"user" => mate_id}, socket) do
    %{user: user} = socket.assigns
    path = Routes.audio_path(socket, :match, user.id, mate_id)
    {:noreply, push_redirect(socket, to: path)}
  end

  defp all_other_user_options(me) do
    import Ecto.Query

    T.Accounts.Profile
    |> where([p], p.user_id != ^me.id)
    |> Ecto.Query.select([p], {p.name, p.user_id})
    |> order_by([p], desc: p.times_liked)
    |> T.Repo.all()
  end
end
