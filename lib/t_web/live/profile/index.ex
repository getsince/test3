defmodule TWeb.ProfileLive.Index do
  use TWeb, :live_view
  alias __MODULE__.Ctx

  @impl true
  def render(assigns) do
    ~H"""
    <div id="blocked-user-listener" class="hidden" phx-hook="BlockedUser"></div>
    <div id="hidden-user-listener" class="hidden" phx-hook="HiddenUser"></div>
    <%= if @live_action == :sort_by_registration do %>
      <div id="profiles" class="p-4 space-y-4" phx-update="append" phx-hook="RegisteredProfilesInfiniteScroll" data-selector="[data-cursor-user-id]">
        <%= for profile <- @profiles do %>
          <.profile profile={profile} />
        <% end %>
      </div>
    <% else %>
      <div id="profiles" class="p-4 space-y-4" phx-update="append" phx-hook="ProfilesInfiniteScroll" data-selector="[data-cursor-user-id]">
        <%= for profile <- @profiles do %>
          <.profile profile={profile} />
        <% end %>
      </div>
    <% end %>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    case socket.assigns.live_action do
      :index ->
        {:ok, paginate_profiles_by_last_active(socket), temporary_assigns: [profiles: []]}

      :sort_by_registration ->
        {:ok, paginate_profiles_by_inserted_at(socket), temporary_assigns: [profiles: []]}
    end
  end

  @impl true
  def handle_event("block", %{"user-id" => user_id}, socket) do
    :ok = Ctx.block_user(user_id)
    {:noreply, push_event(socket, "blocked", %{"user_id" => user_id})}
  end

  @impl true
  def handle_event("hide", %{"user-id" => user_id}, socket) do
    :ok = Ctx.hide_user(user_id)
    {:noreply, push_event(socket, "hidden", %{"user_id" => user_id})}
  end

  def handle_event("more", %{"last_active" => last_active, "user_id" => user_id}, socket) do
    {:noreply, paginate_profiles_by_last_active(socket, last_active, user_id)}
  end

  def handle_event("more", %{"inserted_at" => inserted_at, "user_id" => user_id}, socket) do
    {:noreply, paginate_profiles_by_inserted_at(socket, inserted_at, user_id)}
  end

  defp paginate_profiles_by_last_active(socket) do
    paginate_profiles_by_last_active(socket, _last_active = nil, _user_id = nil)
  end

  defp paginate_profiles_by_inserted_at(socket) do
    paginate_profiles_by_inserted_at(socket, _inserted_at = nil, _user_id = nil)
  end

  defp paginate_profiles_by_last_active(socket, last_active, user_id) do
    assign(socket, profiles: Ctx.paginate_profiles_by_last_active(last_active, user_id))
  end

  defp paginate_profiles_by_inserted_at(socket, inserted_at, user_id) do
    assign(socket, profiles: Ctx.paginate_profiles_by_inserted_at(inserted_at, user_id))
  end

  defp background_image(%{"background" => %{"s3_key" => s3_key}}) do
    %{s3_key: s3_key, url: T.Media.user_imgproxy_cdn_url(s3_key, 500, force_width: true)}
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
    <div id={"profile-" <> @profile.user_id} data-cursor-user-id={@profile.user_id} data-cursor-last-active={@profile.last_active} data-cursor-inserted-at={@profile.inserted_at} class="p-2 rounded-lg border dark:border-gray-700 bg-gray-50 dark:bg-gray-800">
      <div class="flex space-x-2 items-center">
        <p class="font-bold"><%= @profile.name %> <time class="text-gray-500 dark:text-gray-400 font-normal" datetime={@profile.last_active}>was last seen <%= render_relative(@profile.last_active) %></time></p>
        <%= if @profile.blocked_at do %>
          <span class="bg-red-700 px-2 rounded border border-red-500 font-semibold cursor-not-allowed">Blocked <%= render_relative(@profile.blocked_at) %></span>
        <% else %>
          <button phx-click="block" phx-value-user-id={@profile.user_id} class="bg-red-200 dark:bg-red-500 px-2 rounded border border-red-500 dark:border-red-700 font-semibold hover:bg-red-300 dark:hover:bg-red-600 transition" data-confirm={"Are you sure you want to block #{@profile.name}?"}>Block</button>
        <% end %>
        <%= if @profile.hidden do %>
          <span class="bg-red-700 px-2 rounded border border-red-500 font-semibold cursor-not-allowed">Hidden</span>
        <% else %>
          <button phx-click="hide" phx-value-user-id={@profile.user_id} class="bg-red-200 dark:bg-red-500 px-2 rounded border border-red-500 dark:border-red-700 font-semibold hover:bg-red-300 dark:hover:bg-red-600 transition" data-confirm={"Are you sure you want to hide #{@profile.name}?"}>Hide</button>
        <% end %>
      </div>
      <div class="mt-2 flex space-x-2 items-center">
        <p class="text-gray-500 dark:text-gray-400 font-mono text-sm"><%= @profile.user_id %></p>
      </div>
      <%= if @profile.email do %>
      <div class="flex space-x-2 items-center">
        <a href={"mailto:" <> @profile.email} class="text-gray-500 dark:text-gray-400 underline text-sm hover:text-gray-300 transition"><%= @profile.email %></a>
      </div>
      <% end %>

      <div class="mt-2 flex space-x-2 overflow-auto w-full">
        <%= for page <- @profile.story || [] do %>
          <.story_page page={page} />
        <% end %>
      </div>
      <div>
      </div>
    </div>
    """
  end

  defp story_page(%{page: %{"size" => [size_x, size_y]}} = assigns) do
    styles = %{
      "width" => "#{round(size_x / 1.5)}px",
      "height" => "#{round(size_y / 1.5)}px"
    }

    assigns = assign(assigns, style: render_style(styles))

    ~H"""
    <div class="p-1 shrink-0">
    <%= if image = background_image(@page) do %>
      <div class="shrink-0 relative cursor-pointer overflow-y-hidden rounded-lg border border-gray-300 dark:border-gray-700" style={@style} phx-click={JS.toggle(to: "[data-for-image='#{image.s3_key}']")}>
        <img src={image.url} class="w-full h-full rounded-lg object-cover" />
        <div class="absolute top-0 left-0 w-full h-full" data-for-image={image.s3_key}>
          <%= for label <- (@page["labels"] || []) do %>
            <.story_label label={label} size={@page["size"]}/>
          <% end %>
        </div>
      </div>
    <% else %>
      <div class="shrink-0 relative overflow-y-hidden rounded-lg border dark:border-gray-700" style={"background-color:#{background_color(@page)};" <> @style}>
        <%= for label <- (@page["labels"] || []) do %>
          <.story_label label={label} size={@page["size"]} />
        <% end %>
      </div>
    <% end %>
    </div>
    """
  end

  defp story_label(%{label: label, size: [size_width, _size_height]} = assigns) do
    [x, y] = label["position"]

    rotate =
      if rotation = label["rotation"] do
        unless rotation == 0, do: "rotate(#{rotation}deg)"
      end

    scale =
      if zoom = label["zoom"] do
        unless zoom == 1, do: "scale(#{zoom})"
      end

    transform =
      case Enum.reject([rotate, scale], &is_nil/1) do
        [] -> nil
        transforms -> Enum.join(transforms, " ")
      end

    url =
      if answer = label["answer"] do
        T.Media.known_sticker_url(answer)
      end || label["url"]

    if url do
      styles = %{
        "top" => "#{round(y / 1.5)}px",
        "left" => "#{round(x / 1.5)}px",
        "transform-origin" => "top left",
        "transform" => transform,
        "width" => "#{round(size_width / 4.5)}px"
      }

      assigns = assign(assigns, url: url, style: render_style(styles))

      ~H"""
      <img src={@url} class="absolute" style={@style} />
      """
    else
      text_align =
        case label["alignment"] do
          0 -> "left"
          1 -> "center"
          2 -> "right"
          nil -> nil
        end

      styles = %{
        "top" => "#{round(y / 1.5)}px",
        "left" => "#{round(x / 1.5)}px",
        "transform-origin" => "top left",
        "transform" => transform,
        "color" => label["text_color"],
        "text-align" => text_align,
        "font-size" => "12.3px"
      }

      assigns = assign(assigns, style: render_style(styles), alignment: text_align)

      ~H"""
      <div class="absolute font-medium text-white" style={@style}>
        <.text_label text={@label["value"] || @label["answer"] || @label["question"]} alignment={@alignment} bg={@label["background_fill"]} />
      </div>
      """
    end
  end

  defp render_style(styles) do
    styles
    |> Enum.reduce([], fn
      {_k, nil}, acc -> acc
      {k, v}, acc -> [k, ?:, v, ?; | acc]
    end)
    |> IO.iodata_to_binary()
  end

  defp text_label(%{text: text} = assigns) do
    case String.split(text, "\n", trim: true) do
      [_single_line] ->
        style = %{
          "background-color" => assigns[:bg]
        }

        assigns = assign(assigns, style: render_style(style))

        ~H"""
        <span class="bg-black leading-6 px-2 rounded-full inline-block whitespace-nowrap" style={@style}><%= @text %></span>
        """

      lines ->
        count = length(lines)

        {style_top, style_mid, style_bottom} =
          case assigns[:alignment] do
            left when left in ["left", nil] ->
              {
                _top =
                  render_style(%{
                    "background-color" => assigns[:bg],
                    "border-top-right-radius" => "2rem",
                    "border-top-left-radius" => "2rem",
                    "border-bottom-right-radius" => "2rem"
                  }),
                _mid =
                  render_style(%{
                    "background-color" => assigns[:bg],
                    "border-top-right-radius" => "1.8rem",
                    "border-bottom-right-radius" => "1.8rem"
                  }),
                _bottom =
                  render_style(%{
                    "background-color" => assigns[:bg],
                    "border-top-right-radius" => "2rem",
                    "border-bottom-right-radius" => "2rem",
                    "border-bottom-left-radius" => "2rem"
                  })
              }

            "center" ->
              shared =
                render_style(%{"background-color" => assigns[:bg], "border-radius" => "1.9rem"})

              {shared, shared, shared}

            "right" ->
              {
                _top =
                  render_style(%{
                    "background-color" => assigns[:bg],
                    "border-top-right-radius" => "2rem",
                    "border-top-left-radius" => "2rem",
                    "border-bottom-left-radius" => "2rem"
                  }),
                _mid =
                  render_style(%{
                    "background-color" => assigns[:bg],
                    "border-top-left-radius" => "1.8rem",
                    "border-bottom-left-radius" => "1.8rem"
                  }),
                _bottom =
                  render_style(%{
                    "background-color" => assigns[:bg],
                    "border-top-left-radius" => "2rem",
                    "border-bottom-right-radius" => "2rem",
                    "border-bottom-left-radius" => "2rem"
                  })
              }
          end

        lines =
          lines
          |> Enum.with_index(1)
          |> Enum.map(fn {text, idx} ->
            cond do
              idx == 1 -> %{text: text, style: style_top}
              idx == count -> %{text: text, style: style_bottom}
              true -> %{text: text, style: style_mid}
            end
          end)

        assigns = assign(assigns, lines: lines)

        ~H"""
        <%= for line <- @lines do %>
        <p><span class="bg-black leading-6 -my-0.5 px-2 inline-block whitespace-nowrap" style={line.style}><%= line.text %></span></p>
        <% end %>
        """
    end
  end
end

defmodule TWeb.ProfileLive.Index.Ctx do
  @moduledoc false
  import Ecto.Query
  alias T.{Repo, Accounts}
  alias T.Accounts.{Profile, User}

  def paginate_profiles_by_last_active(last_active, user_id) do
    profiles_q = profiles_q() |> order_by([p], desc: p.last_active, desc: p.user_id)

    profiles_q =
      if last_active && user_id do
        where(profiles_q, [p], {p.last_active, p.user_id} < {^last_active, ^user_id})
      else
        profiles_q
      end

    Repo.all(profiles_q)
  end

  def paginate_profiles_by_inserted_at(inserted_at, user_id) do
    profiles_q = profiles_q() |> order_by([p, u], desc: u.inserted_at)

    profiles_q =
      if inserted_at && user_id do
        where(profiles_q, [p, u], u.inserted_at < ^inserted_at)
      else
        profiles_q
      end

    Repo.all(profiles_q)
  end

  defp profiles_q do
    Profile
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
    |> limit(5)
  end

  def block_user(user_id) do
    Accounts.block_user(user_id)
  end

  def hide_user(user_id) do
    Accounts.hide_user(user_id)
  end
end
