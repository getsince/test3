defmodule TWeb.AdminLive.Index do
  use TWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, routes: routes(socket), git_sha: T.Release.git_sha()),
     temporary_assigns: [routes: []]}
  end

  defp routes(socket) do
    [
      Routes.profile_index_path(socket, :index),
      Routes.token_index_path(socket, :index),
      Routes.sticker_index_path(socket, :index)
    ]
  end
end
