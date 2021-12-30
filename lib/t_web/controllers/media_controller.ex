defmodule TWeb.MediaController do
  use TWeb, :controller
  alias T.{Accounts, Calls}

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

  # if it's an audio/aac -> it's for voicemail
  defp upload_form("audio/aac" = content_type) do
    {:ok, %{"key" => key} = fields} = Calls.voicemail_upload_form(content_type)
    %{url: Calls.voicemail_s3_url(), key: key, fields: fields}
  end
end
