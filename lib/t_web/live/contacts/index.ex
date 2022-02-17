defmodule TWeb.ContactLive.Index do
  use TWeb, :live_view
  alias ContactCtx, as: Ctx

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"user_id" => user_id}, _uri, socket) do
    {:noreply, fetch_user(socket, user_id)}
  end

  def handle_params(_params, _uri, socket) do
    user_id = Ctx.fetch_next_user_id()
    {:noreply, push_patch(socket, to: Routes.contact_index_path(socket, :show, user_id))}
  end

  @impl true
  def handle_event("check", %{"id" => user_id, "has-contact" => has_contact}, socket) do
    has_contact? =
      case has_contact do
        "true" -> true
        "false" -> false
      end

    Ctx.check_user(user_id, has_contact?)
    next_user_id = Ctx.fetch_next_user_id()
    {:noreply, push_patch(socket, to: Routes.contact_index_path(socket, :show, next_user_id))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="m-8 text-right flex space-x-7">
      <button phx-click="check" phx-value-id={@user.id} phx-value-has-contact="false" class="w-1/2 h-32 rounded-lg border-2 px-4 py-1 hover:bg-yellow-900 transition text-yellow-500 border-yellow-500">
        <span class="font-semibold"><%= @user.name %> <span class="font-mono">(<%= @user.id %>)</span></span> doesn't have contact
      </button>
      <button phx-click="check" phx-value-id={@user.id} phx-value-has-contact="true" class="w-1/2 h-32 rounded-lg border-2 px-4 py-1 hover:bg-green-900 transition text-green-500 border-green-500">
        <span class="font-semibold"><%= @user.name %> <span class="font-mono">(<%= @user.id %>)</span></span> has contact
      </button>
    </div>
    <ul class="m-8 font-mono border border-gray-600 rounded-lg overflow-hidden divide-y divide-gray-600">
      <%= for {text, idx, candidate?} <- @labels do %>
        <li class={"p-2 bg-gray-800" <> if(candidate?, do: " text-green-400 font-semibold", else: "")}><%= idx %>: <%= text %></li>
      <% end %>
    </ul>
    <div id={"story-" <> @user.id} class="m-8 flex space-x-2">
    <%= for page <- @user.story || [] do %>
      <.story_page page={page} />
    <% end %>
    </div>
    """
  end

  defp fetch_user(socket, user_id) do
    user = Ctx.fetch_user(user_id)

    case labels(user.story) do
      [] ->
        Ctx.check_user(user_id, _has_contact? = false)
        next_user_id = Ctx.fetch_next_user_id()
        push_patch(socket, to: Routes.contact_index_path(socket, :show, next_user_id))

      [_ | _] = labels ->
        assign(socket, user: user, labels: labels)
    end
  end

  defp labels(story) do
    (story || [])
    |> Enum.flat_map(fn page -> page["labels"] || [] end)
    |> Enum.with_index()
    |> Enum.filter(fn {label, _idx} -> label["value"] end)
    |> Enum.map(fn {label, idx} -> {label["value"], idx, could_be_contact?(label["value"])} end)
  end

  defp could_be_contact?(nil), do: false

  defp could_be_contact?(text) do
    text |> String.downcase() |> String.contains?(["@", "tg", "ig", "inst", "тг", "инст", "@"])
  end

  defp story_page(assigns) do
    ~H"""
    <%= if image = background_image(@page) do %>
      <div class="relative cursor-pointer" phx-click={JS.toggle(to: "[data-for-image='#{image.s3_key}']")}>
        <img src={image.url} class="rounded-lg border border-gray-300 dark:border-gray-700 w-56" />
        <div class="absolute space-y-1 top-0 left-0 p-4" data-for-image={image.s3_key}>
        <%= for label <- render_labels(@page) do %>
          <p class="bg-gray-100 dark:bg-black rounded px-1.5 font-medium leading-6 inline-block"><%= label %></p>
        <% end %>
        </div>
      </div>
    <% else %>
      <div class="rounded-lg border dark:border-gray-700 w-64 h-full space-y-1 p-4 overflow-auto" style={"background-color:#{background_color(@page)}"}>
      <%= for label <- render_labels(@page) do %>
        <p class="bg-gray-100 dark:bg-black rounded px-1.5 font-medium leading-6 inline-block"><%= label %></p>
      <% end %>
      </div>
    <% end %>
    """
  end

  defp background_image(%{"background" => %{"s3_key" => s3_key}}) do
    %{s3_key: s3_key, url: T.Media.user_imgproxy_cdn_url(s3_key, 250, force_width: true)}
  end

  defp background_image(_other), do: nil

  defp background_color(%{"background" => %{"color" => color}}) do
    color
  end

  defp background_color(_other), do: nil

  defp render_labels(%{"labels" => labels}) do
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

  defp render_labels(_other), do: []
end

defmodule ContactCtx do
  import Ecto.Query
  alias T.{Repo, Accounts}

  def check_user(user_id, has_text_contact?) do
    now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

    Repo.insert_all(
      "checked_profiles",
      [
        %{
          user_id: Ecto.UUID.dump!(user_id),
          has_text_contact?: has_text_contact?,
          inserted_at: now,
          updated_at: now
        }
      ],
      on_conflict: {:replace, [:user_id, :has_text_contact?, :updated_at]},
      conflict_target: [:user_id]
    )
  end

  def fetch_next_user_id do
    Accounts.Profile
    |> join(:left, [p], c in "checked_profiles", on: p.user_id == c.user_id)
    |> where([p, c], is_nil(c.user_id))
    |> select([p], p.user_id)
    |> order_by([p], desc: :last_active)
    |> limit(1)
    |> Repo.one!()
  end

  def fetch_user(user_id) do
    Accounts.Profile
    |> where(user_id: ^user_id)
    |> select([p], %{id: p.user_id, name: p.name, story: p.story})
    |> Repo.one!()
  end
end
