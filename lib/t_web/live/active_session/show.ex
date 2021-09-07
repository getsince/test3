defmodule TWeb.ActiveSessionLive.Show do
  @moduledoc false
  use TWeb, :live_view

  alias TWeb.ActiveSessionLive.Context
  alias T.{Feeds, Matches, Calls}

  @default_assigns [
    user_options: [],
    feed: []
  ]

  @impl true
  def mount(%{"user_id" => user_id}, _session, socket) do
    if Context.user_exists?(user_id) do
      if connected?(socket) do
        :ok = Feeds.subscribe_for_activated_sessions()
        :ok = Feeds.subscribe_for_deactivated_sessions()
        :ok = Feeds.subscribe_for_invites(user_id)
        :ok = Matches.subscribe_for_user(user_id)
        # :ok = Context.subscribe_for_calls(user_id)
      end

      {:ok,
       socket
       |> assign(@default_assigns)
       |> assign(page_title: Context.username(user_id), me_id: user_id),
       temporary_assigns: [user_options: [], feed: []]}
    else
      {:ok, push_redirect(socket, to: Routes.active_session_index_path(socket, :index))}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    if call_id = socket.assigns[:call_id] do
      :ok = Calls.end_call(call_id)
    end

    socket =
      socket
      |> assign(call_id: nil, call_role: nil)
      |> assign(user_options: Context.list_user_options())
      |> update_feed()

    {:noreply, apply_action(params, socket.assigns.live_action, socket)}
  end

  defp apply_action(%{"call_id" => call_id}, :call, socket) do
    me = socket.assigns.me_id

    case Calls.get_call_role_and_peer(call_id, me) |> IO.inspect() do
      {:ok, :caller, _profile} ->
        assign(socket, call_id: call_id, call_role: :caller)

      {:ok, :called, _profile} ->
        assign(socket, call_id: call_id, call_role: :called)

      {:error, :ended} ->
        socket
        |> put_flash(:error, "call ended")
        |> push_patch(to: Routes.active_session_show_path(socket, :show, me))

      {:error, :not_found} ->
        socket
        |> put_flash(:error, "call not found")
        |> push_patch(to: Routes.active_session_show_path(socket, :show, me))
    end
  end

  defp apply_action(_params, _action, socket), do: socket

  @impl true
  def handle_event(
        "activate-session",
        %{"session" => %{"duration" => duration, "user_id" => user_id}},
        socket
      ) do
    duration = String.to_integer(duration)
    Feeds.activate_session(user_id, duration)
    me_id = socket.assigns.me_id
    {:noreply, push_redirect(socket, to: Routes.active_session_show_path(socket, :show, me_id))}
  end

  def handle_event("deactivate-session", %{"user" => user_id}, socket) do
    Feeds.deactivate_session(user_id)
    {:noreply, update_feed(socket)}
  end

  def handle_event("pick-user", %{"user" => user_id}, socket) do
    {:noreply, push_redirect(socket, to: Routes.active_session_show_path(socket, :show, user_id))}
  end

  def handle_event("invite", %{"user" => user_id}, socket) do
    _invited? = Feeds.invite_active_user(socket.assigns.me_id, user_id)
    {:noreply, socket}
  end

  def handle_event("like", %{"user" => user_id}, socket) do
    Matches.like_user(socket.assigns.me_id, user_id)
    {:noreply, update_feed(socket)}
  end

  def handle_event("unmatch", %{"match" => match_id}, socket) do
    Matches.unmatch_match(socket.assigns.me_id, match_id)
    {:noreply, update_feed(socket)}
  end

  def handle_event("call", %{"user" => _user_id}, socket) do
    # me = socket.assigns.me_id

    # socket =
    #   case Context.call(me, user_id) do
    #     {:ok, call_id} ->
    #       push_patch(socket, to: Routes.active_session_show_path(socket, :call, me, call_id))

    #     {:error, reason} ->
    #       socket |> put_flash(:error, reason)
    #   end

    {:noreply, socket}
  end

  @impl true
  def handle_info({Feeds, :activated, _user_id}, socket) do
    {:noreply, update_feed(socket)}
  end

  def handle_info({Feeds, :deactivated, _user_id}, socket) do
    {:noreply, update_feed(socket)}
  end

  defp update_feed(socket) do
    user_id = socket.assigns.me_id
    matches = Context.list_matches(user_id)
    missed_calls = Context.list_missed_calls(user_id)
    invites = Context.list_invites(user_id)
    active_sessions = Context.list_active_sessions()

    feed = matches ++ missed_calls ++ invites ++ active_sessions
    assign(socket, feed: feed)
  end

  defp feed_item_row(assigns) do
    ~H"""
    <tr class={row_class(@item)}>
      <td class="border-r dark:border-gray-700 text-xs text-center">
        <%= live_redirect @item.user_name,
          to: Routes.active_session_show_path(TWeb.Endpoint, :show, @item.user_id),
          class: "font-semibold text-blue-600 hover:text-blue-400 dark:text-blue-200 dark:hover:text-blue-600 transition" %>
      </td>
      <td class="border-r dark:border-gray-700 text-xs p-2">
        <%= if @item.session_id do %>
          <pre><%= Jason.encode_to_iodata!(%{"id" => @item.session_id, "expires_at" => @item.expires_at}, pretty: true) %></pre>
        <% end %>
      </td>
      <td class="border-r dark:border-gray-700 text-xs p-2">
        <pre><%= extra_info(@item) %></pre>
      </td>
      <td class="p-2 text-center">
        <.button_actions item={@item}></.button_actions>
      </td>
    </tr>
    """
  end

  @common_row_class "border-b dark:border-gray-700"

  defp row_class(%{match: _match}),
    do: [@common_row_class, " bg-green-300 bg-opacity-20 dark:bg-green-900 dark:bg-opacity-20"]

  defp row_class(%{call: _match}),
    do: [@common_row_class, " bg-yellow-300 bg-opacity-10 dark:bg-yellow-900 dark:bg-opacity-20"]

  defp row_class(%{invite: _match}),
    do: [@common_row_class, " bg-blue-300 bg-opacity-20 dark:bg-blue-900 dark:bg-opacity-20"]

  defp row_class(_default), do: @common_row_class

  defp extra_info(%{match: match}), do: Jason.encode_to_iodata!(%{"match" => match}, pretty: true)
  defp extra_info(%{call: call}), do: Jason.encode_to_iodata!(%{"call" => call}, pretty: true)

  defp extra_info(%{invite: invite}),
    do: Jason.encode_to_iodata!(%{"invite" => invite}, pretty: true)

  defp extra_info(_other), do: nil

  defp button_actions(%{item: %{match: _}} = assigns) do
    ~H"""
    <div>
      <button phx-click="call" phx-value-user={@item.user_id} class="border rounded text-green-600 border-green-600 px-2 font-medium hover:bg-green-600 hover:text-white translation">Call</button>
      <button phx-click="deactivate-session" phx-value-user={@item.user_id} class="ml-2 border rounded text-pink-600 border-pink-600 px-2 font-medium hover:bg-pink-600 hover:text-white translation">Deactivate</button>
      <button phx-click="unmatch" phx-value-match={@item.match.id} class="ml-2 border rounded text-pink-600 border-pink-600 px-2 font-medium hover:bg-pink-600 hover:text-white translation">Unmatch</button>
    </div>
    """
  end

  defp button_actions(%{item: %{call: %{session_id: session_id}}} = assigns)
       when not is_nil(session_id) do
    ~H"""
    <div>
      <button phx-click="call" phx-value-user={@item.user_id} class="border rounded text-green-600 border-green-600 px-2 font-medium hover:bg-green-600 hover:text-white translation">Call</button>
      <button phx-click="like" phx-value-user={@item.user_id} class="ml-2 border rounded text-green-600 border-green-600 px-2 font-medium hover:bg-green-600 hover:text-white translation">Like</button>
      <button phx-click="deactivate-session" phx-value-user={@item.user_id} class="ml-2 border rounded text-pink-600 border-pink-600 px-2 font-medium hover:bg-pink-600 hover:text-white translation">Deactivate</button>
    </div>
    """
  end

  defp button_actions(%{item: %{invite: _invite}} = assigns) do
    ~H"""
    <div>
      <button phx-click="call" phx-value-user={@item.user_id} class="border rounded text-green-600 border-green-600 px-2 font-medium hover:bg-green-600 hover:text-white translation">Call</button>
      <button phx-click="like" phx-value-user={@item.user_id} class="ml-2 border rounded text-green-600 border-green-600 px-2 font-medium hover:bg-green-600 hover:text-white translation">Like</button>
      <button phx-click="deactivate-session" phx-value-user={@item.user_id} class="ml-2 border rounded text-pink-600 border-pink-600 px-2 font-medium hover:bg-pink-600 hover:text-white translation">Deactivate</button>
    </div>
    """
  end

  defp button_actions(assigns) do
    ~H"""
    <div>
      <button phx-click="like" phx-value-user={@item.user_id} class="border rounded text-green-600 border-green-600 px-2 font-medium hover:bg-green-600 hover:text-white translation">Like</button>
      <button phx-click="invite" phx-value-user={@item.user_id} class="ml-2 border rounded text-blue-600 border-blue-600 px-2 font-medium hover:bg-blue-600 hover:text-white translation">Invite</button>
      <button phx-click="deactivate-session" phx-value-user={@item.user_id} class="ml-2 border rounded text-pink-600 border-pink-600 px-2 font-medium hover:bg-pink-600 hover:text-white translation">Deactivate</button>
    </div>
    """
  end
end
