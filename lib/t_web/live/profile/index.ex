defmodule TWeb.ProfileLive.Index do
  use TWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 space-y-4">
    <%= for {profile, stats} <- @profiles do %>
      <div class="p-2 rounded border dark:border-gray-700 bg-gray-50 dark:bg-gray-800">
        <div class="flex space-x-2 items-center">
          <p class="font-bold"><%= profile.name %> <time class="text-gray-500 dark:text-gray-400 font-normal" datetime={profile.last_active}>was last seen <%= render_relative(profile.last_active) %></time></p>
          <%= if profile.user.blocked_at do %>
            <span class="bg-red-700 px-2 rounded border border-red-500 font-semibold cursor-not-allowed">Blocked <%= render_relative(profile.user.blocked_at) %></span>
          <% else %>
            <button phx-click="block" phx-value-user-id={profile.user_id} class="bg-red-200 dark:bg-red-500 px-2 rounded border border-red-500 dark:border-red-700 font-semibold hover:bg-red-300 dark:hover:bg-red-600 transition" data-confirm={"Are you sure you want to block #{profile.name}?"}>Block</button>
          <% end %>
        </div>
        <div class="flex space-x-2 items-center">
          <p class="text-gray-500 dark:text-gray-400 font-normal"><%= profile.user_id %></p>
        </div>
        <div class="flex space-x-2 items-center">
          <p class="text-gray-500 dark:text-gray-400 font-normal"><%= profile.user.email %></p>
        </div>
        <div class="mt-2 flex space-x-2 items-start overflow-y-auto">
          <div class="mt-1 text-sm text-gray-500">
            <p class="text-gray-500 dark:text-gray-400 font-semibold tracking-wider">Stats</p>
            <table class="border mt-1">
              <tbody>
                <tr>
                  <td class="border border-gray-300 dark:border-gray-600 px-2">#calls</td>
                  <td class="border border-gray-300 dark:border-gray-600 px-2"><%= stats.calls_count %></td>
                </tr>
              </tbody>
            </table>
          </div>
          <%= for page <- profile.story || [] do %>
            <%= if image = background_image(page) do %>
              <div class="relative cursor-pointer" phx-click={JS.toggle(to: "[data-for-image='#{image.s3_key}']")}>
                <img src={image.url} class="rounded-lg border border-gray-300 dark:border-gray-700 w-56" />
                <div class="absolute space-y-1 top-0 left-0 p-4" data-for-image={image.s3_key}>
                <%= for label <- labels(page) do %>
                  <p class="bg-gray-100 dark:bg-black rounded px-1.5 font-medium leading-6 inline-block"><%= label %></p>
                <% end %>
                </div>
              </div>
            <% else %>
              <div class="rounded-lg border dark:border-gray-700 w-64 h-full space-y-1 p-4 overflow-auto" style={"background-color:#{background_color(page)}"}>
              <%= for label <- labels(page) do %>
                <p class="bg-gray-100 dark:bg-black rounded px-1.5 font-medium leading-6 inline-block"><%= label %></p>
              <% end %>
              </div>
            <% end %>
          <% end %>
        </div>
        <div>
        </div>
      </div>
    <% end %>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, fetch_profiles(socket)}
  end

  @impl true
  def handle_event("block", %{"user-id" => user_id}, socket) do
    :ok = T.Accounts.block_user(user_id)
    {:noreply, fetch_profiles(socket)}
  end

  defp fetch_profiles(socket) do
    import Ecto.Query

    profiles =
      T.Accounts.Profile
      |> join(:inner, [p], u in T.Accounts.User, on: p.user_id == u.id)
      |> join(:left, [p, u], c in T.Calls.Call,
        on: c.caller_id == p.user_id or c.called_id == p.user_id
      )
      |> order_by(desc: :last_active)
      |> group_by([p, u], [p.user_id, u.id])
      |> Ecto.Query.select([p, u, c], {%{p | user: u}, %{calls_count: count(c)}})
      |> T.Repo.all()

    assign(socket, profiles: profiles)
  end

  defp background_image(%{"background" => %{"s3_key" => s3_key}}) do
    %{s3_key: s3_key, url: T.Media.user_imgproxy_cdn_url(s3_key, 400)}
  end

  defp background_image(_other), do: nil

  defp background_color(%{"background" => %{"color" => color}}) do
    color
  end

  defp background_color(_other), do: nil

  defp labels(%{"labels" => labels}) do
    labels
    |> Enum.map(fn
      %{"value" => value} ->
        value

      %{"url" => url} ->
        String.split(url, "/")
        |> Enum.at(-1)
        |> String.split("?")
        |> Enum.at(0)
        |> URI.decode()

      _other ->
        nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp labels(_other), do: []

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
end
