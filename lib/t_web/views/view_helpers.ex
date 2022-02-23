defmodule TWeb.ViewHelpers do
  @moduledoc false
  alias T.Media

  @type env :: :feed | :match | :profile

  @spec postprocess_story([map], pos_integer(), env) :: [map]
  def postprocess_story(story, screen_width, env) when is_list(story) do
    Enum.map(story, fn page ->
      page |> blur(screen_width, env) |> add_bg_url(screen_width) |> add_label_urls()
    end)
  end

  def postprocess_news(story, screen_width) when is_list(story) do
    Enum.map(story, fn page ->
      page |> blur(screen_width, :feed) |> add_bg_url(screen_width)
    end)
  end

  defp blur(%{"blurred" => %{"s3_key" => s3_key} = bg}, screen_width, :feed) do
    bg = Map.merge(bg, s3_key_urls(s3_key, screen_width))
    %{"blurred" => bg, "private" => true}
  end

  defp blur(%{"blurred" => _blurred} = page, _screen_width, :match) do
    page |> Map.delete("blurred") |> Map.put("private", true)
  end

  defp blur(%{"blurred" => %{"s3_key" => s3_key} = bg} = page, screen_width, :profile) do
    bg = Map.merge(bg, s3_key_urls(s3_key, screen_width))
    page |> Map.put("blurred", bg) |> Map.put("private", true)
  end

  defp blur(page, _screen_width, _env), do: page

  defp add_bg_url(page, screen_width) do
    case page do
      %{"background" => %{"s3_key" => key} = bg} = page when not is_nil(key) ->
        bg = Map.merge(bg, s3_key_urls(key, screen_width))
        %{page | "background" => bg}

      _ ->
        page
    end
  end

  defp add_label_urls(%{"labels" => labels} = page) do
    %{page | "labels" => add_urls_to_labels(labels)}
  end

  defp add_label_urls(page) do
    page
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
