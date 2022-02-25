defmodule TWeb.StoryLive.Index do
  use TWeb, :live_view
  alias StoryCtx, as: Ctx

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"user_id" => user_id}, _uri, socket) do
    {:noreply, fetch_user(socket, user_id)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, user: nil)}
  end

  @impl true
  def handle_event("save", %{"story" => new_story}, socket) do
    user = socket.assigns.user
    Ctx.cas_story(user.id, user.story, Jason.decode!(new_story))
    {:noreply, push_patch(socket, to: Routes.story_index_path(socket, :show, user.id))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= if @user do %>
    <div class="m-8 text-center">
      <span class="font-semibold"><%= @user.name %> <span class="font-mono">(<%= @user.id %>)</span></span>
    </div>
    <form phx-submit="save" class="mx-8">
      <button type="submit" class="mt-4 w-full border-2 border-green-500 rounded-lg h-16 transition text-green-500 hover:bg-green-900 font-semibold">Save</button>
      <label class="mt-2 block w-full">
        Story
        <textarea class="rounded w-full bg-gray-600 font-mono" style="height:600px;"name="story"><%= Jason.encode_to_iodata!(@user.story, pretty: true) %></textarea>
      </label>
    </form>
    <div class="m-8 flex space-x-2 overflow-auto w-full">
    <%= for page <- @user.story || [] do %>
      <.story_page page={page} />
    <% end %>
    </div>
    <% else %>
      <div>paste the user id in the url</div>
    <% end %>
    """
  end

  defp fetch_user(socket, user_id) do
    user = Ctx.fetch_user(user_id)
    assign(socket, user: user)
  end

  defp story_page(%{page: %{"size" => [size_x, size_y]}} = assigns) do
    styles = %{
      "width" => "#{size_x}px",
      "height" => "#{size_y}px"
    }

    assigns = assign(assigns, style: render_style(styles))

    ~H"""
    <div class="p-1 shrink-0">
    <%= if image = background_image(@page) do %>
      <div class="shrink-0 relative cursor-pointer rounded-lg border border-gray-300 dark:border-gray-700" style={@style} phx-click={JS.toggle(to: "[data-for-image='#{image.s3_key}']")}>
        <img src={image.url} class="w-full h-full rounded-lg object-cover" />
        <div class="absolute top-0 left-0 w-full h-full" data-for-image={image.s3_key}>
          <%= for label <- (@page["labels"] || []) do %>
            <.story_label label={label} size={@page["size"]}/>
          <% end %>
        </div>
      </div>
    <% else %>
      <div class="shrink-0 relative rounded-lg border dark:border-gray-700" style={"background-color:#{background_color(@page)};" <> @style}>
        <%= for label <- (@page["labels"] || []) do %>
          <.story_label label={label} size={@page["size"]} />
        <% end %>
      </div>
    <% end %>
    </div>
    """
  end

  defp story_label(%{label: label, size: [size_width, _size_height]} = assigns) do
    [x, y] = label["position"] || label["center"]

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
        "top" => "#{y}px",
        "left" => "#{x}px",
        "transform-origin" => "top left",
        "transform" => transform,
        "width" => "#{round(size_width / 3)}px"
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
        "top" => "#{y}px",
        "left" => "#{x}px",
        "transform-origin" => "top left",
        "transform" => transform,
        "color" => label["text_color"],
        "text-align" => text_align
      }

      assigns = assign(assigns, style: render_style(styles))

      ~H"""
      <div class="absolute text-sm font-medium" style={@style}>
        <%= for line <- String.split(@label["value"] || @label["answer"], "\n") do %>
          <p><span class="bg-black leading-8 px-3 inline-block whitespace-nowrap" style={render_style(%{"background-color" => label["background_fill"]})}><%= line %></span></p>
        <% end %>
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

  defp background_image(%{"background" => %{"s3_key" => s3_key}}) do
    %{s3_key: s3_key, url: T.Media.user_imgproxy_cdn_url(s3_key, 250, force_width: true)}
  end

  defp background_image(_other), do: nil

  defp background_color(%{"background" => %{"color" => color}}) do
    color
  end

  defp background_color(_other), do: nil
end

defmodule StoryCtx do
  import Ecto.Query
  alias T.{Repo, Accounts}

  def fetch_user(user_id) do
    Accounts.Profile
    |> where(user_id: ^user_id)
    |> select([p], %{id: p.user_id, name: p.name, story: p.story})
    |> Repo.one!()
  end

  defp current_story(user_id) do
    Accounts.Profile
    |> where(user_id: ^user_id)
    |> select([p], p.story)
    |> Repo.one!()
  end

  defp replace_story(user_id, story) do
    Accounts.Profile
    |> where(user_id: ^user_id)
    |> Repo.update_all(set: [story: story])
  end

  def cas_story(user_id, prev_story, new_story) do
    Repo.transaction(fn ->
      current_story = current_story(user_id)

      if prev_story == current_story do
        replace_story(user_id, new_story)
      else
        raise "#{user_id}'s story has changed while you were editing!"
      end
    end)
  end
end
