defmodule T.Media.S3DeleteJob do
  @moduledoc """
  Deletes objects from s3.
  """

  use Oban.Worker

  @impl true
  def perform(%Oban.Job{args: %{"bucket" => bucket, "s3_key" => s3_key}}) do
    %Finch.Response{status: 204} =
      T.Media.s3_request(method: :delete, url: T.Media.s3_url(bucket), path: s3_key)

    :ok
  end
end
