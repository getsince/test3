defmodule TWeb.ActiveSessionLive.Index do
  @moduledoc false
  use TWeb, :live_view

  alias TWeb.ActiveSessionLive.Context
  alias T.Feeds

  @default_assigns [
    page_title: "Active Sessions",
    user_options: []
  ]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :ok = Feeds.subscribe_for_activated_sessions()
      :ok = Feeds.subscribe_for_deactivated_sessions()
    end

    {:ok, assign(socket, @default_assigns), temporary_assigns: [user_options: []]}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      assign(socket,
        active_sessions: Context.list_active_sessions(),
        user_options: Context.list_user_options()
      )

    {:noreply, apply_action(params, socket.assigns.live_action, socket)}
  end

  defp apply_action(_params, :index, socket) do
    socket
  end

  defp apply_action(_params, :new, socket) do
    socket
  end

  @impl true
  def handle_event(
        "activate-session",
        %{"session" => %{"duration" => duration, "user_id" => user_id}},
        socket
      ) do
    duration = String.to_integer(duration)
    Feeds.activate_session(user_id, duration)
    {:noreply, push_patch(socket, to: Routes.active_session_index_path(socket, :index))}
  end

  def handle_event("deactivate-session", %{"user-id" => user_id}, socket) do
    Feeds.deactivate_session(user_id)
    {:noreply, assign(socket, active_sessions: Context.list_active_sessions())}
  end

  def handle_event("pick-user", %{"user" => user_id}, socket) do
    {:noreply, push_redirect(socket, to: Routes.active_session_show_path(socket, :show, user_id))}
  end

  @impl true
  def handle_info({Feeds, :activated, _user_id}, socket) do
    {:noreply, assign(socket, active_sessions: Context.list_active_sessions())}
  end

  def handle_info({Feeds, :deactivated, _user_id}, socket) do
    {:noreply, assign(socket, active_sessions: Context.list_active_sessions())}
  end

  defp button_actions(assigns) do
    ~L"""
    <div>
      <button phx-click="deactivate-session" phx-value-user-id="<%= @user_id %>" class="border rounded text-pink-600 border-pink-600 px-2 font-medium hover:bg-pink-600 hover:text-white translation">Deactivate</button>
    </div>
    """
  end
end
