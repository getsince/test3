defmodule TWeb.TokenLive.Index do
  use TWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    users_with_tokens =
      if connected?(socket) do
        T.Accounts.list_all_users_with_session_tokens()
      else
        []
      end

    {:ok, assign(socket, users_with_tokens: users_with_tokens),
     temporary_assigns: [users_with_tokens: []]}
  end
end
