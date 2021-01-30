defmodule T.Media.RemoteStorage.S3 do
  @moduledoc false
  @behaviour T.Media.RemoteStorage
  alias T.Media

  @impl true
  def file_exists?(key) do
    Media.bucket()
    |> ExAws.S3.head_object(key)
    |> ExAws.request()
    |> case do
      {:ok, %{status_code: 200}} -> true
      {:error, {:http_error, 404, %{status_code: 404}}} -> false
    end
  end
end
