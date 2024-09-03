defmodule SinceWeb.SearchLive.Index do
  use SinceWeb, :live_view
  alias __MODULE__.Ctx

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, search: nil, profile: nil)}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) when byte_size(search) > 0 do
    {:noreply, assign(socket, search: search, profile: Ctx.search_profile(search))}
  end

  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, assign(socket, search: search, profile: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen w-full">
      <form class="m-4" phx-change="search" phx-submit="search">
        <div class="relative flex items-center">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="w-4 h-4 absolute ml-3 text-gray-500"
          >
            <circle cx="11" cy="11" r="8"></circle>
            <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
          </svg>
          <input
            type="search"
            name="search"
            value={@search}
            phx-debounce="100"
            placeholder="0000017c-14c7-9745-0242-ac1100020000"
            class="rounded dark:bg-gray-800 bg-gray-50 shadow border-gray-300 dark:border-gray-600 pl-9"
          />
        </div>
      </form>

      <%= if @profile do %>
        <div id="profile" class="mx-2 flex flex-wrap">
          <.profile profile={@profile} />
        </div>
      <% end %>
    </div>
    """
  end

  defp profile(assigns), do: SinceWeb.ProfileLive.Index.profile(assigns)
end

defmodule SinceWeb.SearchLive.Index.Ctx do
  import Ecto.Query
  alias Since.{Repo, Accounts.Profile, Accounts.User}

  def search_profile(user_id) do
    case Ecto.Bigflake.UUID.cast(user_id) do
      {:ok, _id} ->
        Profile
        |> where(user_id: ^user_id)
        |> join(:inner, [p], u in User, on: p.user_id == u.id)
        |> select([p, u], %{
          user_id: p.user_id,
          name: p.name,
          email: u.email,
          last_active: p.last_active,
          story: p.story,
          blocked_at: u.blocked_at,
          inserted_at: u.inserted_at,
          hidden: p.hidden?
        })
        |> Repo.one()

      :error ->
        nil
    end
  end
end
