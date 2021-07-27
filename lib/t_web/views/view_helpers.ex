defmodule TWeb.ViewHelpers do
  @moduledoc false
  alias T.Media

  def extract_song_info(%{
        "data" => [
          %{
            "id" => id,
            "attributes" => %{
              "artistName" => artist_name,
              "artwork" => %{"url" => album_cover},
              "name" => song_name,
              "previews" => [%{"url" => preview_url}]
            }
          }
        ]
      }) do
    album_cover = String.replace(album_cover, ["{w}", "{h}"], "1000")

    %{
      "id" => id,
      "artist_name" => artist_name,
      "album_cover" => album_cover,
      "song_name" => song_name,
      "preview_url" => preview_url
    }
  end

  def postprocess_story(story, screen_width) when is_list(story) do
    story
    |> Enum.map(fn
      %{"background" => %{"s3_key" => key} = bg} = page when not is_nil(key) ->
        bg = Map.merge(bg, s3_key_urls(key, screen_width))
        %{page | "background" => bg}

      other_page ->
        other_page
    end)
    |> Enum.map(fn %{"labels" => labels} = page ->
      %{page | "labels" => add_urls_to_labels(labels)}
    end)
  end

  defp add_urls_to_labels(labels) do
    Enum.map(labels, fn label ->
      if answer = label["answer"] do
        if url = Media.known_sticker_url(answer) do
          Map.put(label, "url", url)
        end
      end || label
    end)
  end

  defp s3_key_urls(key, width) when is_binary(key) do
    %{"proxy" => Media.user_imgproxy_cdn_url(key, width)}
  end
end
