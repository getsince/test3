defmodule TWeb.AdminLive.Index do
  use TWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, routes: routes(socket)), temporary_assigns: [routes: []]}
  end

  defp routes(socket) do
    [
      # Routes.match_index_path(socket, :index),
      Routes.token_index_path(socket, :index),
      Routes.sticker_index_path(socket, :index)
      # Routes.support_index_path(socket, :index),
      # Routes.trace_index_path(socket, :index)
    ]
  end
end
