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
  def handle_event("check", %{"id" => user_id}, socket) do
    Ctx.check_user(user_id)
    next_user_id = Ctx.fetch_next_user_id()
    {:noreply, push_patch(socket, to: Routes.contact_index_path(socket, :show, next_user_id))}
  end

  def handle_event("migrate", params, socket) do
    %{"page" => page_id, "label" => label_id, "replacement" => replacement} = params
    user = socket.assigns.user

    page_id = String.to_integer(page_id)
    label_id = String.to_integer(label_id)
    replacement = Ctx.parse_replacement(replacement)

    new_story = Ctx.add_contacts(user.story, page_id, label_id, replacement)
    prev_story = user.story
    Ctx.cas_story(user.id, prev_story, new_story)

    {:noreply, push_patch(socket, to: Routes.contact_index_path(socket, :show, user.id))}
  end

  def handle_event("populate", %{"page" => page_id, "label" => label_id}, socket) do
    {:noreply,
     assign(socket, page_id: String.to_integer(page_id), label_id: String.to_integer(label_id))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="m-8 text-right flex space-x-7">
      <button phx-click="check" phx-value-id={@user.id} class="w-full h-16 rounded-lg border-2 px-4 py-1 hover:bg-yellow-900 transition text-yellow-500 border-yellow-500">
        mark <span class="font-semibold"><%= @user.name %> <span class="font-mono">(<%= @user.id %>)</span></span> checked
      </button>
    </div>
    <form phx-submit="migrate" class="mx-8">
      <div class="flex space-x-2">
        <label class="w-1/2">Page: <input type="number" id="page" name="page" class="rounded block w-full bg-gray-600" value={@page_id} /></label>
        <label class="w-1/2">Label: <input type="number" id="label" name="label" class="rounded block w-full bg-gray-600" value={@label_id} /></label>
      </div>
      <label class="mt-2 block w-full">
        Replacement
        <textarea class="rounded w-full bg-gray-600" name="replacement" placeholder="telegram,durov"></textarea>
      </label>
      <button type="submit" class="mt-4 w-full border-2 border-green-500 rounded-lg h-16 transition text-green-500 hover:bg-green-900 font-semibold">Migrate</button>
    </form>
    <ul class="m-8 font-mono border border-gray-600 rounded-lg overflow-hidden divide-y divide-gray-600">
      <%= for {text, page_id, label_id, candidate?} <- labels(@user.story) do %>
        <li phx-click="populate" phx-value-page={to_string(page_id)} phx-value-label={to_string(label_id)} class={"p-2 bg-gray-800 cursor-pointer hover:bg-gray-700 " <> if(candidate?, do: " text-green-400 font-semibold", else: "")}>[<%= page_id %>][<%= label_id %>] <%= text %></li>
      <% end %>
    </ul>
    <div id={"story-" <> @user.id} class="m-8 flex space-x-2 overflow-auto w-full">
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
        Ctx.check_user(user_id)
        next_user_id = Ctx.fetch_next_user_id()
        push_patch(socket, to: Routes.contact_index_path(socket, :show, next_user_id))

      [_ | _] = labels ->
        assign(socket, user: user, labels: labels, page_id: nil, label_id: nil)
    end
  end

  defp labels(story) do
    (story || [])
    |> Enum.with_index()
    |> Enum.flat_map(fn {page, page_idx} ->
      (page["labels"] || [])
      |> Enum.with_index()
      |> Enum.filter(fn {label, _idx} -> label["value"] || label["answer"] end)
      |> Enum.map(fn {label, label_idx} ->
        value = label["value"] || label["answer"]
        {value, page_idx, label_idx, could_be_contact?(value)}
      end)
    end)
  end

  defp could_be_contact?(nil), do: false

  defp could_be_contact?(text) do
    text |> String.downcase() |> String.contains?(["@", "tg", "ig", "inst", "тг", "инст", "@"])
  end

  defp story_page(%{page: %{"size" => [size_x, size_y]}} = assigns) do
    styles = %{
      "width" => "#{size_x / 2}px",
      "height" => "#{size_y / 2}px"
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
        "top" => "#{round(y / 2)}px",
        "left" => "#{round(x / 2)}px",
        "transform-origin" => "top left",
        "transform" => transform,
        "width" => "#{round(size_width / 6)}px"
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
        "top" => "#{round(y / 2)}px",
        "left" => "#{round(x / 2)}px",
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

defmodule ContactCtx do
  import Ecto.Query
  alias T.{Repo, Accounts}

  def check_user(user_id) do
    now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

    Repo.insert_all(
      "checked_profiles",
      [
        %{
          user_id: Ecto.UUID.dump!(user_id),
          inserted_at: now,
          updated_at: now
        }
      ],
      on_conflict: {:replace, [:user_id, :updated_at]},
      conflict_target: [:user_id]
    )
  end

  def fetch_next_user_id do
    Accounts.Profile
    |> join(:left, [p], c in "checked_profiles", on: p.user_id == c.user_id)
    |> where([p, c], is_nil(c.user_id))
    |> select([p], p.user_id)
    # |> order_by([p], desc: :last_active)
    |> limit(1)
    |> Repo.one!()
  end

  def fetch_user(user_id) do
    Accounts.Profile
    |> where(user_id: ^user_id)
    |> select([p], %{id: p.user_id, name: p.name, story: p.story})
    |> Repo.one!()
  end

  def parse_replacement(raw) do
    lines = String.split(raw, "\n", trim: true)

    Enum.map(lines, fn line ->
      case String.split(line, ",") do
        [k, v] -> %{k: parse_key(k), v: v, dx: 0, dy: 0}
        [k, v, dx] -> %{k: parse_key(k), v: v, dx: parse_int(dx), dy: 0}
        [k, v, dx, dy] -> %{k: parse_key(k), v: v, dx: parse_int(dx), dy: parse_int(dy)}
      end
    end)
  end

  defp parse_key(""), do: :keep

  defp parse_key("t"), do: "telegram"
  defp parse_key("tg"), do: "telegram"
  defp parse_key("tlg"), do: "telegram"
  defp parse_key("telegram" = tg), do: tg

  defp parse_key("i"), do: "instagram"
  defp parse_key("ig"), do: "instagram"
  defp parse_key("inst"), do: "instagram"
  defp parse_key("instagram" = ig), do: ig

  defp parse_key("w"), do: "whatsapp"
  defp parse_key("wa"), do: "whatsapp"
  defp parse_key("whatsapp" = wa), do: wa

  defp parse_int(""), do: 0
  defp parse_int(int), do: String.to_integer(int)

  def add_contacts(story, page_id, label_id, replacement) do
    %{"labels" => old_labels} = old_page = Enum.at(story, page_id)
    old_label = Enum.at(old_labels, label_id)

    new_labels =
      old_labels
      |> List.replace_at(label_id, new_labels(old_label, replacement))
      |> List.flatten()

    new_page = %{old_page | "labels" => new_labels}
    List.replace_at(story, page_id, new_page)
  end

  defp new_labels(old_label, replacement) do
    [Map.put(old_label, "text-contact", true) | new_labels_cont(old_label, replacement)]
  end

  defp new_labels_cont(old_label, [%{k: :keep, v: new_text} | replacement]) do
    new_label = old_label |> Map.put("value", new_text) |> Map.put("text-change", true)
    [new_label | new_labels_cont(old_label, replacement)]
  end

  defp new_labels_cont(old_label, [instruction | replacement]) do
    %{"position" => [x, y]} = old_label
    %{k: k, v: v, dx: dx, dy: dy} = instruction

    contact =
      old_label
      |> Map.take(["zoom", "rotation"])
      |> Map.merge(%{"question" => k, "answer" => v, "position" => [x + dx, y + dy]})

    [contact | new_labels_cont(old_label, replacement)]
  end

  defp new_labels_cont(_old_label, []) do
    []
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

  # TODO restore story
end
