defmodule TWeb.StickerLive.Index do
  use TWeb, :live_view
  alias T.Media

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> fetch_stickers()
      |> assign(page_title: "Stickers")
      |> allow_upload(:sticker,
        accept: ~w[.png .svg .jpg .jpeg],
        auto_upload: true,
        max_entries: 50,
        external: &presign_upload/2,
        progress: &handle_progress/3
      )

    {:ok, socket, temporary_assigns: [stickers: []]}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen w-full" phx-drop-target={@uploads.sticker.ref}>
      <h2 class="text-lg p-4 flex items-center">
        Stickers
        <form class="ml-2 h-full flex items-center" action="#" method="post" phx-change="validate-upload-form" phx-submit="submit-upload-form">
          <label class="flex items-center">
            <div class="bg-gray-200 dark:bg-gray-700 rounded p-1 hover:bg-gray-300 dark:hover:bg-gray-600 transition cursor-pointer">
              <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="w-4 h-4"><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></svg>
            </div>
            <span class="ml-2 text-sm text-gray-600 dark:text-gray-500">(or drag-and-drop anywhere)</span>
            <%= live_file_input @uploads.sticker, class: "hidden" %>
          </label>
        </form>
      </h2>

      <div class="flex flex-wrap">
      <%= for entry <- @uploads.sticker.entries do %>
        <div class="flex items-center w-full md:w-1/2 lg:w-1/3 p-3 bg-yellow-100 dark:bg-blue-900 transition">
          <%= live_img_preview entry, class: "w-36 h-36 object-contain hover:bg-gray-200 dark:hover:bg-blue-800 transition" %>

          <div class="ml-4">
            <p class="font-semibold mb-2"><%= entry.client_name %></p>
            <p class="text-sm text-gray-700 dark:text-gray-300">progress: <%= entry.progress %>%</p>

            <%= for err <- upload_errors(@uploads.sticker, entry) do %>
              <p class="text-sm text-red-300 dark:text-gray-300"><%= error_to_string(err) %></p>
            <% end %>

            <button phx-click="cancel-upload" phx-value-ref={entry.ref} class="mt-2 leading-6 px-2 rounded bg-red-200 dark:bg-red-800 text-red-700 dark:text-red-300 hover:bg-red-300 dark:hover:bg-red-500 transition">cancel</button>
          </div>
        </div>
      <% end %>

      <%= for sticker <- @stickers do %>
        <div class="flex items-center w-full md:w-1/2 lg:w-1/3 p-3 hover:bg-gray-100 dark:hover:bg-gray-800 transition">
          <img src={Media.sticker_cache_busting_cdn_url(sticker)} class="w-36 h-36 object-contain hover:bg-gray-200 transition"/>
          <div class="ml-4">
            <p class="font-semibold mb-2"><%= sticker.key %></p>
            <%= if size = sticker.meta[:size] do %>
              <p class="text-sm text-gray-700 dark:text-gray-300">size: <%= format_bytes(size) %></p>
            <% end %>
            <%= if last_modified = sticker.meta[:last_modified] do %>
              <p class="text-sm text-gray-700 dark:text-gray-300">last modified: <%= last_modified %></p>
            <% end %>
            <button phx-click="delete-sticker" phx-value-key={sticker.key} class="mt-2 leading-6 px-2 rounded bg-red-200 dark:bg-red-800 text-red-700 dark:text-red-300 hover:bg-red-300 dark:hover:bg-red-500 transition">delete</button>
          </div>
        </div>
      <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event(form_event, _params, socket)
      when form_event in ["validate-upload-form", "submit-upload-form"] do
    {:noreply, socket}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :sticker, ref)}
  end

  def handle_event("delete-sticker", %{"key" => key}, socket) do
    Media.delete_sticker_by_key(key)
    {:noreply, socket}
  end

  defp fetch_stickers(socket) do
    stickers = Enum.sort_by(Media.known_stickers(), & &1.meta[:last_modified], :desc)
    assign(socket, stickers: stickers)
  end

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"

  defp presign_upload(entry, socket) do
    uploads = socket.assigns.uploads
    key = entry.client_name |> Media.fix_macos_unicode() |> trim_extension()

    config = Media.presign_config()
    bucket = Media.static_bucket()

    {:ok, fields} =
      Media.sign_form_upload(config, bucket,
        key: key,
        content_type: entry.client_type,
        max_file_size: uploads.sticker.max_file_size,
        expires_in: :timer.hours(1)
      )

    meta = %{uploader: "S3", key: key, url: Media.static_s3_url(), fields: fields}
    {:ok, meta, socket}
  end

  defp handle_progress(:sticker, entry, socket) do
    if entry.done? do
      consume_uploaded_entry(socket, entry, fn meta -> Media.sticker_uploaded(meta.key) end)
    end

    {:noreply, socket}
  end

  defp format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes >= memory_unit(:TB) -> format_bytes(bytes, :TB)
      bytes >= memory_unit(:GB) -> format_bytes(bytes, :GB)
      bytes >= memory_unit(:MB) -> format_bytes(bytes, :MB)
      bytes >= memory_unit(:KB) -> format_bytes(bytes, :KB)
      true -> format_bytes(bytes, :B)
    end
  end

  defp format_bytes(bytes) when is_binary(bytes) do
    format_bytes(String.to_integer(bytes))
  end

  defp format_bytes(bytes, :B) when is_integer(bytes), do: "#{bytes} B"

  defp format_bytes(bytes, unit) when is_integer(bytes) do
    value = bytes / memory_unit(unit)
    "#{:erlang.float_to_binary(value, decimals: 1)} #{unit}"
  end

  defp memory_unit(:TB), do: 1024 * 1024 * 1024 * 1024
  defp memory_unit(:GB), do: 1024 * 1024 * 1024
  defp memory_unit(:MB), do: 1024 * 1024
  defp memory_unit(:KB), do: 1024

  defp trim_extension(s3_key) do
    extname = Path.extname(s3_key)
    String.replace_trailing(s3_key, extname, "")
  end
end
