defmodule TWeb.TokenLive.Index do
  use TWeb, :live_view
  alias __MODULE__.Ctx

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, search: nil, users: [])}
  end

  @impl true
  def handle_params(%{"user_id" => user_id}, _uri, socket) do
    {:noreply, assign(socket, user_id: user_id, tokens: Ctx.list_tokens(user_id))}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, user_id: nil, tokens: [])}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) when byte_size(search) > 0 do
    {:noreply, assign(socket, search: search, users: Ctx.search_users(search))}
  end

  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, assign(socket, search: search, users: [])}
  end

  def handle_event("close", _params, socket) do
    {:noreply, push_patch(socket, to: Routes.token_index_path(socket, :index))}
  end

  def handle_event("add-token", _params, socket) do
    token = Ctx.add_token(socket.assigns.user_id)
    {:noreply, update(socket, :tokens, fn tokens -> [token | tokens] end)}
  end

  def handle_event("remove-token", %{"token" => token, "context" => context}, socket) do
    Ctx.remove_token(token, context)
    raw_token = T.Accounts.UserToken.raw_token(token)

    {:noreply,
     update(socket, :tokens, fn tokens ->
       Enum.reject(tokens, fn token -> token.token == raw_token end)
     end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen w-full">
      <form class="m-4" phx-change="search" phx-submit="search">
        <div class="relative flex items-center">
          <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="w-4 h-4 absolute ml-2 text-gray-500"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg>
          <input type="search" name="search" value={@search} phx-debounce="100" placeholder="Apple" class="rounded bg-gray-800 pl-8" />
        </div>
      </form>

      <div id="users" class="mx-2 flex flex-wrap">
        <%= for user <- @users do %>
          <.user_card user={user} />
        <% end %>
      </div>

      <%= if @live_action == :show do %>
        <div id={"tokens-" <> @user_id} class="fixed top-0 left-0 w-full h-full overflow-auto opacity-100 phx-modal" phx-capture-click="close" phx-window-keydown="close" phx-key="escape" phx-page-loading>
          <div class="mt-10 max-w-2xl mx-auto rounded border dark:border-gray-600 bg-white dark:bg-gray-800 overflow-hidden">
            <div class="flex items-center justify-between p-4 bg-gray-100 dark:bg-gray-700 border-b dark:border-gray-600">
              <div class="flex items-center space-x-4">
                <span class="text-2xl font-bold">Session tokens</span>
                <button phx-click="add-token" class="bg-green-900 border border-green-600 font-semibold px-2 leading-7 rounded hover:bg-green-800 transition">Add token</button>
              </div>
              <%= live_patch "✕", to: Routes.token_index_path(@socket, :index), class: "text-lg" %>
            </div>
            <div id="tokens" class="space-y-2 p-2">
              <%= for token <- @tokens do %>
                <.token token={token} />
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp user_card(assigns) do
    ~H"""
    <div class="p-2 w-1/2 sm:w-1/4 lg:w-1/6 xl:w-1/8">
    <%= live_patch id: "user-" <> @user.id, to: Routes.token_index_path(TWeb.Endpoint, :show, @user.id) do %>
      <div class="rounded border p-2 bg-gray-800 text-gray-600 border-gray-700 hover:bg-blue-800 hover:border-blue-700 hover:text-blue-400 transition">
        <div class="text-xs truncate"><%= @user.last_active %></div>
        <div class="font-semibold text-lg text-white truncate"><%= @user.name %></div>
      </div>
    <% end %>
    </div>
    """
  end

  defp token(%{token: %{id: token_id, token: raw_token}} = assigns) do
    assigns =
      assign(assigns,
        inserted_at: datetime(token_id),
        encoded_token: T.Accounts.UserToken.encoded_token(raw_token)
      )

    ~H"""
    <div>
      <div class="space-x-1 text-gray-400 bg-gray-700 border-gray-600 text-xs inline-block rounded-t border-t border-r border-l divide-x divide-gray-600 select-none">
        <span class="px-2"><%= @token.context %></span>
        <span class="px-2"><%= @inserted_at %></span>
        <span class="px-2"><%= @token.version || "no version info" %></span>
      </div>
      <div class="flex space-x-2">
        <p id={"token-" <> @token.id} class="font-mono bg-gray-700 border-gray-600 rounded-b rounded-r border px-1 py-1 inline-block">
          <%= @encoded_token %>
        </p>
        <button phx-click="remove-token" phx-value-token={@encoded_token} phx-value-context={@token.context} class="bg-red-900 border px-2 border-red-700 rounded hover:bg-red-700 transition">
          Delete
        </button>
      </div>
    </div>
    """
  end

  defp datetime(<<_::288>> = uuid) do
    datetime(Ecto.Bigflake.UUID.dump!(uuid))
  end

  defp datetime(<<unix::64, _rest::64>>) do
    unix |> DateTime.from_unix!(:millisecond) |> DateTime.truncate(:second)
  end
end

defmodule TWeb.TokenLive.Index.Ctx do
  import Ecto.Query
  alias T.{Repo, Accounts.Profile, Accounts.UserToken}

  def search_users(name) do
    pattern = "%" <> String.trim(name) <> "%"

    Profile
    |> where([p], ilike(p.name, ^pattern))
    |> select([p], %{id: p.user_id, name: p.name, last_active: p.last_active})
    |> order_by([p], desc: :last_active)
    |> Repo.all()
  end

  def list_tokens(user_id) do
    UserToken
    |> where(user_id: ^user_id)
    |> select([t], map(t, [:id, :token, :context, :version]))
    |> order_by(desc: :id)
    |> Repo.all()
  end

  def add_token(user_id) do
    # TODO context=admin
    {_token, user_token} = UserToken.build_token(user_id, "mobile")
    user_token |> Repo.insert!() |> Map.take([:id, :token, :context, :version])
  end

  def remove_token(token, context) do
    TWeb.UserAuth.log_out_mobile_user(token, context)
  end
end
