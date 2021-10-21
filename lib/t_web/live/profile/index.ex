defmodule TWeb.ProfileLive.Index do
  use TWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 space-y-4">
    <%= for profile <- @profiles do %>
      <div class="p-2 rounded border dark:border-gray-700 bg-gray-50 dark:bg-gray-800">
        <div class="flex space-x-2 items-center">
          <p class="font-bold"><%= profile.name %></p>
          <%= if profile.user.blocked_at do %>
            <span class="bg-red-700 px-2 rounded border border-red-500 font-semibold cursor-not-allowed">Blocked</span>
          <% else %>
            <button phx-click="block" phx-value-user-id={profile.user_id} class="bg-red-600 px-2 rounded border border-red-400 font-semibold hover:bg-red-700 transition" data-confirm={"Are you sure you want to block #{profile.name}?"}>Block</button>
          <% end %>
        </div>
        <div class="mt-2 flex space-x-2">
          <%= for s3_key <- s3_keys(profile.story) do %>
            <img src={s3_url(s3_key)} class="rounded border dark:border-gray-700 w-64" />
          <% end %>
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
      |> order_by(desc: :last_active)
      |> Ecto.Query.select([p, u], %{p | user: u})
      |> T.Repo.all()

    assign(socket, profiles: profiles)
  end

  defp s3_keys(_story = nil), do: []

  defp s3_keys(story) do
    story
    |> Enum.map(fn
      %{"background" => %{"s3_key" => s3_key}} -> s3_key
      %{"background" => _} -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp s3_url(s3_key) do
    T.Media.user_s3_url(s3_key)
  end
end
