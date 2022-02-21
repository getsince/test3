defmodule TWeb.ProfileLive.Index do
  use TWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div id="blocked-user-listener" class="hidden" phx-hook="BlockedUser"></div>
    <div id="profiles" class="p-4 space-y-4" phx-update="append" phx-hook="ProfilesInfiniteScroll" data-selector="[data-cursor-user-id]">
      <%= for {profile, stats} <- @profiles do %>
        <.profile profile={profile} stats={stats} />
      <% end %>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, paginate_profiles(socket), temporary_assigns: [profiles: []]}
  end

  @impl true
  def handle_event("block", %{"user-id" => user_id}, socket) do
    :ok = T.Accounts.block_user(user_id)
    {:noreply, push_event(socket, "blocked", %{"user_id" => user_id})}
  end

  def handle_event("more", %{"last_active" => last_active, "user_id" => user_id}, socket) do
    {:noreply, paginate_profiles(socket, last_active, user_id)}
  end

  defp paginate_profiles(socket) do
    paginate_profiles(socket, _last_active = nil, _user_id = nil)
  end

  defp paginate_profiles(socket, last_active, user_id) do
    import Ecto.Query

    alias T.Repo
    alias T.Calls.Call
    alias T.Accounts.{Profile, User}

    profiles_q =
      Profile
      |> join(:inner, [p], u in User, on: p.user_id == u.id)
      |> join(:left, [p, u], c in Call, on: c.caller_id == p.user_id or c.called_id == p.user_id)
      |> order_by([p], desc: p.last_active, desc: p.user_id)
      |> group_by([p, u], [p.user_id, u.id])
      |> limit(5)
      |> Ecto.Query.select([p, u, c], {%{p | user: u}, %{calls_count: count(c)}})

    profiles_q =
      if last_active && user_id do
        where(profiles_q, [p], {p.last_active, p.user_id} < {^last_active, ^user_id})
      else
        profiles_q
      end

    assign(socket, profiles: Repo.all(profiles_q))
  end

  defp background_image(%{"background" => %{"s3_key" => s3_key}}) do
    %{s3_key: s3_key, url: T.Media.user_imgproxy_cdn_url(s3_key, 250, force_width: true)}
  end

  defp background_image(_other), do: nil

  defp background_color(%{"background" => %{"color" => color}}) do
    color
  end

  defp background_color(_other), do: nil

  defp render_relative(date) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, date)

    cond do
      diff < 60 -> "less than a minute ago"
      diff < 2 * 60 -> "a minute ago"
      diff < 3600 -> "#{div(diff, 60)} minutes ago"
      diff < 2 * 3600 -> "an hour ago"
      diff < 24 * 3600 -> "#{div(diff, 3600)} hours ago"
      diff < 2 * 24 * 3600 -> "a day ago"
      diff < 7 * 24 * 3600 -> "#{div(diff, 24 * 3600)} days ago"
      true -> "more than a week ago, on #{DateTime.to_date(date)}"
    end
  end

  defp profile(assigns) do
    ~H"""
    <div id={"profile-" <> @profile.user_id} data-cursor-user-id={@profile.user_id} data-cursor-last-active={@profile.last_active} class="p-2 rounded border dark:border-gray-700 bg-gray-50 dark:bg-gray-800">
      <div class="flex space-x-2 items-center">
        <p class="font-bold"><%= @profile.name %> <time class="text-gray-500 dark:text-gray-400 font-normal" datetime={@profile.last_active}>was last seen <%= render_relative(@profile.last_active) %></time></p>
        <%= if @profile.user.blocked_at do %>
          <span class="bg-red-700 px-2 rounded border border-red-500 font-semibold cursor-not-allowed">Blocked <%= render_relative(@profile.user.blocked_at) %></span>
        <% else %>
          <button phx-click="block" phx-value-user-id={@profile.user_id} class="bg-red-200 dark:bg-red-500 px-2 rounded border border-red-500 dark:border-red-700 font-semibold hover:bg-red-300 dark:hover:bg-red-600 transition" data-confirm={"Are you sure you want to block #{@profile.name}?"}>Block</button>
        <% end %>
      </div>
      <div class="flex space-x-2 items-center">
        <p class="text-gray-500 dark:text-gray-400 font-normal"><%= @profile.user_id %></p>
      </div>
      <div class="flex space-x-2 items-center">
        <p class="text-gray-500 dark:text-gray-400 font-normal"><%= @profile.user.email %></p>
      </div>
      <div class="mt-2 flex space-x-2">
        <div class="mt-1 text-sm text-gray-500">
          <p class="text-gray-500 dark:text-gray-400 font-semibold tracking-wider">Stats</p>
          <table class="border mt-1">
            <tbody>
              <tr>
                <td class="border border-gray-300 dark:border-gray-600 px-2">#calls</td>
                <td class="border border-gray-300 dark:border-gray-600 px-2"><%= @stats.calls_count %></td>
              </tr>
            </tbody>
          </table>
        </div>
        <div class="flex space-x-2 overflow-auto w-full">
        <%= for page <- @profile.story || [] do %>
          <.story_page page={page} />
        <% end %>
        </div>
      </div>
      <div>
      </div>
    </div>
    """
  end

  defp story_page(%{page: %{"size" => [size_x, size_y]}} = assigns) do
    assigns = assign(assigns, style: "width:#{size_x / 2}px;height:#{size_y / 2}px;")

    ~H"""
    <%= if image = background_image(@page) do %>
      <div class="shrink-0 relative cursor-pointer overflow-hidden rounded-lg border border-gray-300 dark:border-gray-700" style={@style} phx-click={JS.toggle(to: "[data-for-image='#{image.s3_key}']")}>
        <img src={image.url} class="w-full h-full object-cover" />
        <div class="absolute space-y-1 top-0 left-0 p-4 w-full h-full overflow-auto" data-for-image={image.s3_key}>
        <%= for label <- (@page["labels"] || []) do %>
          <.story_label label={label} />
        <% end %>
        </div>
      </div>
    <% else %>
      <div class="shrink-0 rounded-lg border dark:border-gray-700 space-y-1 p-4 overflow-auto" style={"background-color:#{background_color(@page)};" <> @style}>
      <%= for label <- (@page["labels"] || []) do %>
        <.story_label label={label} />
      <% end %>
      </div>
    <% end %>
    """
  end

  defp story_label(%{label: label} = assigns) do
    text_color =
      if text_color = label["text_color"] do
        "color:" <> text_color
      end

    bg_color =
      if bg_color = label["background_fill"] do
        "background-color:" <> bg_color
      end

    style = Enum.join([text_color, bg_color], ";")
    assigns = assign(assigns, style: style)

    ~H"""
    <p class="bg-gray-100 dark:bg-black rounded px-1.5 font-medium leading-6 inline-block" style={@style}><%= @label["value"] %></p>
    """
  end
end
