defmodule TWeb.TraceLive.Index do
  use TWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, user_options: all_user_options())}
  end

  @impl true
  def handle_event("submit", %{"user" => user_id}, socket) do
    path = Routes.trace_show_path(socket, :show, user_id)
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
