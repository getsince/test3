defmodule TWeb.ViewHelpers do
  @moduledoc false
  alias T.{Media, Games}

  @type env :: :feed | :match | :profile

  @spec postprocess_story([map], String.t(), pos_integer(), env) :: [map]
  def postprocess_story(story, version, screen_width, env) when is_list(story) do
    Enum.map(story, fn page ->
      page
      |> blur(screen_width, env)
      |> add_bg_urls(screen_width)
      |> process_labels(version, screen_width)
    end)
  end

  def process_sticker(sticker, screen_width), do: process_label(sticker, screen_width)

  defp blur(%{"blurred" => %{"s3_key" => s3_key} = bg}, screen_width, :feed) do
    bg = maybe_put(bg, "proxy", image_cdn_url(s3_key, screen_width))
    %{"blurred" => bg, "private" => true}
  end

  defp blur(%{"blurred" => _blurred} = page, _screen_width, :match) do
    page |> Map.delete("blurred") |> Map.put("private", true)
  end

  defp blur(%{"blurred" => %{"s3_key" => s3_key} = bg} = page, screen_width, :profile) do
    bg = maybe_put(bg, "proxy", image_cdn_url(s3_key, screen_width))
    page |> Map.put("blurred", bg) |> Map.put("private", true)
  end

  defp blur(page, _screen_width, _env), do: page

  defp add_bg_urls(page, screen_width) do
    case page do
      %{"background" => %{"video_s3_key" => video_key, "s3_key" => placeholder_key} = bg} = page
      when not is_nil(video_key) ->
        bg =
          bg
          |> maybe_put("proxy", image_cdn_url(placeholder_key, screen_width))
          |> maybe_put("video_url", media_cdn_url(video_key))

        %{page | "background" => bg}

      %{"background" => %{"s3_key" => key} = bg} = page when not is_nil(key) ->
        bg = maybe_put(bg, "proxy", image_cdn_url(key, screen_width))
        %{page | "background" => bg}

      _ ->
        page
    end
  end

  defp process_labels(%{"labels" => labels} = page, _version, screen_width) do
    labels =
      labels
      |> Enum.reduce([], fn label, acc -> [process_label(label, screen_width) | acc] end)
      |> :lists.reverse()

    %{page | "labels" => labels}
  end

  defp process_labels(page, _version, _screen_width), do: page

  defp process_label(
         %{"question" => "video", "s3_key" => key, "video_s3_key" => video_s3_key} = label,
         screen_width
       ) do
    label
    |> Map.put("url", media_cdn_url(video_s3_key))
    |> Map.put("proxy", image_cdn_url(key, screen_width))
  end

  defp process_label(%{"question" => "photo", "s3_key" => key} = label, screen_width) do
    Map.put(label, "proxy", image_cdn_url(key, screen_width))
  end

  defp process_label(%{"question" => "audio", "s3_key" => key} = label, _screen_width) do
    Map.put(label, "url", media_cdn_url(key))
  end

  defp process_label(%{"question" => "telegram", "answer" => handle} = label, _screen_width) do
    Map.put(label, "url", "https://t.me/" <> handle)
  end

  defp process_label(%{"question" => "instagram", "answer" => handle} = label, _screen_width) do
    Map.put(label, "url", "https://instagram.com/" <> handle)
  end

  defp process_label(%{"question" => "whatsapp", "answer" => handle} = label, _screen_width) do
    Map.put(label, "url", "https://wa.me/" <> handle)
  end

  defp process_label(%{"question" => "snapchat", "answer" => handle} = label, _screen_width) do
    Map.put(label, "url", "https://www.snapchat.com/add/" <> handle)
  end

  defp process_label(%{"question" => "messenger", "answer" => handle} = label, _screen_width) do
    Map.put(label, "url", "https://m.me/" <> handle)
  end

  defp process_label(%{"question" => "signal", "answer" => handle} = label, _screen_width) do
    Map.put(label, "url", "https://signal.me/#p/" <> handle)
  end

  defp process_label(%{"question" => "twitter", "answer" => handle} = label, _screen_width) do
    Map.put(label, "url", "https://twitter.com/" <> handle)
  end

  defp process_label(%{"question" => q} = label, _screen_width) when q in ["phone", "email"] do
    label
  end

  defp process_label(
         %{"question" => "compliment", "prompt" => prompt, "gender" => gender} = label,
         _screen_width
       ) do
    %{
      "text" => Games.render(prompt),
      "push_text" => push_text(prompt, gender),
      "emoji" => Games.prompts()[prompt] || "❤️"
    }
    |> Map.merge(label)
  end

  defp process_label(%{"answer" => a} = label, _screen_width) do
    if url = Media.known_sticker_url(a) do
      Map.put(label, "url", url)
    else
      label
    end
  end

  defp process_label(label, _screen_width), do: label

  defp image_cdn_url(key, width) when is_binary(key) do
    Media.user_imgproxy_cdn_url(key, width)
  end

  defp image_cdn_url(nil, _width), do: nil

  defp media_cdn_url(key) when is_binary(key) do
    Media.media_cdn_url(key)
  end

  defp push_text(prompt, gender), do: Games.render(prompt <> "_push_" <> gender)

  defp maybe_put(map, _k, nil), do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)
end
