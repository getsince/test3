defmodule SinceWeb.MediaController do
  use SinceWeb, :controller
  alias Since.Accounts

  def create_upload_form(conn, %{"media" => params}) do
    content_type =
      case params do
        %{"content-type" => content_type} -> content_type
        %{"extension" => extension} -> MIME.type(extension)
      end

    json(conn, upload_form(content_type))
  end

  # if it's an image -> it's for profile story photo
  defp upload_form("image/" <> _rest = content_type) do
    {:ok, %{"key" => key} = fields} = Accounts.photo_upload_form(content_type)
    %{url: Accounts.photo_s3_url(), key: key, fields: fields}
  end

  # if it's an audio/aac -> it's for profile story voice sticker
  defp upload_form("audio/aac" = content_type) do
    {:ok, %{"key" => key} = fields} = Accounts.media_upload_form(content_type)
    %{url: Accounts.media_s3_url(), key: key, fields: fields}
  end

  # if it's an video/mp4 -> it's for profile story video background
  defp upload_form("video/mp4" = content_type) do
    {:ok, %{"key" => key} = fields} = Accounts.media_upload_form(content_type)
    %{url: Accounts.media_s3_url(), key: key, fields: fields}
  end
end
