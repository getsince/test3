defmodule TWeb.MediaController do
  use TWeb, :controller
  alias T.Accounts

  def create_upload_form(conn, %{"media" => params}) do
    "image/" <> _rest =
      content_type =
      case params do
        %{"content-type" => content_type} -> content_type
        %{"extension" => extension} -> MIME.type(extension)
      end

    {:ok, %{"key" => key} = fields} = Accounts.photo_upload_form(content_type)
    url = Accounts.photo_s3_url()

    json(conn, %{url: url, key: key, fields: fields})
  end
end
