defmodule T.Media.S3Client do
  @behaviour T.Media.Client

  @impl true
  def list_objects(bucket) do
    client = T.AWS.client()

    {:ok, %{"ListBucketResult" => %{"IsTruncated" => "false", "Contents" => contents}},
     %{status_code: 200}} = AWS.S3.list_objects_v2(client, bucket)

    contents
  end
end
