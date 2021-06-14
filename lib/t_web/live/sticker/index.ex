defmodule TWeb.StickerLive.Index do
  use TWeb, :live_view
  alias T.Media

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(:timer.seconds(1), :refresh)
    end

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
  def handle_event("validate-upload-form", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("submit-upload-form", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :sticker, ref)}
  end

  def handle_event("delete-sticker", %{"key" => key}, socket) do
    Media.delete_sticker_by_key(key)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply, fetch_stickers(socket)}
  end

  defp fetch_stickers(socket) do
    stickers = Media.Static.list() |> Enum.sort_by(& &1.meta[:last_modified], :desc)
    assign(socket, stickers: stickers)
  end

  def error_to_string(:too_large), do: "Too large"
  def error_to_string(:too_many_files), do: "You have selected too many files"
  def error_to_string(:not_accepted), do: "You have selected an unacceptable file type"

  defp presign_upload(entry, socket) do
    uploads = socket.assigns.uploads
    key = entry.client_name

    config = Media.eu_north_presign_config()
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
      consume_uploaded_entry(socket, entry, fn _meta -> :ok end)
      Media.Static.notify_s3_updated()
    end

    {:noreply, socket}
  end

  def format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes >= memory_unit(:TB) -> format_bytes(bytes, :TB)
      bytes >= memory_unit(:GB) -> format_bytes(bytes, :GB)
      bytes >= memory_unit(:MB) -> format_bytes(bytes, :MB)
      bytes >= memory_unit(:KB) -> format_bytes(bytes, :KB)
      true -> format_bytes(bytes, :B)
    end
  end

  def format_bytes(bytes) when is_binary(bytes) do
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
end
