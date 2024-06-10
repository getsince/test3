defmodule Since.Media.S3DeleteJob do
  @moduledoc """
  Deletes objects from s3.
  """

  use Oban.Worker

  @impl true
  def perform(%Oban.Job{args: %{"bucket" => bucket, "s3_key" => s3_key}}) do
    {:ok, %{status_code: 204}} =
      bucket
      |> ExAws.S3.delete_object(s3_key)
      |> ExAws.request()

    :ok
  end
end
