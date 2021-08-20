defmodule TWeb.ViewHelpers do
  @moduledoc false
  alias T.Media

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
