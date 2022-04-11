defmodule T.StoryBackground do
  @moduledoc false

  def fix_story(nil), do: nil

  def fix_story(story) when is_list(story) do
    Enum.map(story, fn
      %{"background" => background} = page ->
        maybe_proxy_url = background["proxy"]

        case maybe_proxy_url do
          nil ->
            page

          _ ->
            background =
              background
              |> Map.put_new("s3_key", s3_key_from_proxy_url(maybe_proxy_url))
              |> Map.delete("proxy")

            %{page | "background" => background}
        end

      page ->
        page
    end)
  end

  defp s3_key_from_proxy_url("https://d3r9yicn85nax9.cloudfront.net/" <> path) do
    "https://since-when-are-you-happy.s3.amazonaws.com/" <> s3_key =
      path |> String.split("/") |> List.last() |> Base.decode64!(padding: false)

    s3_key
  end
end
