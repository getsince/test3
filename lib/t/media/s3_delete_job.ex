defmodule T.Media.S3DeleteJob do
  @moduledoc """
  Deletes objects from s3.
  """

  use Oban.Worker

  @impl true
  def perform(%Oban.Job{args: %{"bucket" => bucket, "s3_key" => key}}) do
    client = T.AWS.client()
    {:ok, _, %{status_code: 204}} = AWS.S3.delete_object(client, bucket, key, %{})
    :ok
  end
end
