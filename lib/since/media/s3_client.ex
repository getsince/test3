defmodule Since.Media.S3Client do
  @behaviour T.Media.Client

  @impl true
  def list_objects(bucket) do
    %{status_code: 200, body: %{is_truncated: "false", contents: contents}} =
      bucket
      |> ExAws.S3.list_objects()
      |> ExAws.request!()

    contents
  end
end
