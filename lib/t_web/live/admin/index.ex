defmodule TWeb.AdminLive.Index do
  use TWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, routes: routes(), git_sha: T.Release.git_sha()),
     temporary_assigns: [routes: []]}
  end

  defp routes do
    [
      ~p"/admin/profiles",
      ~p"/admin/tokens",
      ~p"/admin/stickers",
      ~p"/admin/workflows"
    ]
  end
end
