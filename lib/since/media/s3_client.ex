defmodule Since.Media.S3Client do
  @behaviour Since.Media.Client

  @impl true
  def list_objects(bucket) do
    %Finch.Response{status: 200, body: body} =
      Since.Media.s3_request(
        method: :get,
        url: Since.Media.s3_url(bucket),
        query: %{"list-type" => 2}
      )

    {:ok, {"ListBucketResult", list_bucket_result}} = S3.xml(body)

    ["false"] = :proplists.get_value("IsTruncated", list_bucket_result)

    Enum.reduce(list_bucket_result, [], fn attr, acc ->
      case attr do
        {"Contents", contents} ->
          object =
            Enum.reduce(contents, %{}, fn {key, value}, acc ->
              case key do
                "Key" -> Map.put(acc, :key, value)
                "ETag" -> Map.put(acc, :e_tag, value)
                "LastModified" -> Map.put(acc, :last_modified, value)
                "Size" -> Map.put(acc, :size, value)
              end
            end)

          [object | acc]

        _ ->
          acc
      end
    end)
  end
end
