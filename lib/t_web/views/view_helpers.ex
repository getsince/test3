defmodule TWeb.ViewHelpers do
  @moduledoc false
  alias T.Media
  alias T.Accounts

  @type env :: :feed | :match | :profile

  @spec postprocess_story([map], String.t(), pos_integer(), env) :: [map]
  def postprocess_story(story, version, screen_width, env) when is_list(story) do
    Enum.map(story, fn page ->
      page
      |> blur(screen_width, env)
      |> add_bg_url(screen_width)
      |> process_labels(version)
    end)
  end

  defp blur(%{"blurred" => %{"s3_key" => s3_key} = bg}, screen_width, :feed) do
    bg = Map.merge(bg, s3_key_image_urls(s3_key, screen_width))
    %{"blurred" => bg, "private" => true}
  end

  defp blur(%{"blurred" => _blurred} = page, _screen_width, :match) do
    page |> Map.delete("blurred") |> Map.put("private", true)
  end

  defp blur(%{"blurred" => %{"s3_key" => s3_key} = bg} = page, screen_width, :profile) do
    bg = Map.merge(bg, s3_key_image_urls(s3_key, screen_width))
    page |> Map.put("blurred", bg) |> Map.put("private", true)
  end

  defp blur(page, _screen_width, _env), do: page

  defp add_bg_url(page, screen_width) do
    case page do
      %{"background" => %{"s3_key" => key} = bg} = page when not is_nil(key) ->
        bg = Map.merge(bg, s3_key_image_urls(key, screen_width))
        %{page | "background" => bg}

      _ ->
        page
    end
  end

  defp process_labels(%{"labels" => labels} = page, version) do
    # we do not add url for versions prior to 6.2.0 because they will be rendered incorrectly
    labels =
      case Version.compare(version, "6.2.0") do
        :lt ->
          labels
          |> Enum.reduce([], fn label, acc ->
            case label do
              %{"s3_key" => _key, "question" => "audio"} -> acc
              label -> [process_label(label) | acc]
            end
          end)

        _ ->
          labels
          |> Enum.reduce([], fn label, acc ->
            case label do
              %{"s3_key" => key, "question" => "audio"} ->
                label = Map.put(label, "url", Accounts.voice_url(key))
                [label | acc]

              label ->
                [process_label(label) | acc]
            end
          end)
      end
      |> :lists.reverse()

    %{page | "labels" => labels}
  end

  defp process_labels(page, _version), do: page

  defp process_label(%{"question" => "telegram", "answer" => handle} = label) do
    Map.put(label, "url", "https://t.me/" <> handle)
  end

  defp process_label(%{"question" => "instagram", "answer" => handle} = label) do
    Map.put(label, "url", "https://instagram.com/" <> handle)
  end

  defp process_label(%{"question" => "whatsapp", "answer" => handle} = label) do
    Map.put(label, "url", "https://wa.me/" <> handle)
  end

  defp process_label(%{"question" => "snapchat", "answer" => handle} = label) do
    Map.put(label, "url", "https://www.snapchat.com/add/" <> handle)
  end

  defp process_label(%{"question" => "messenger", "answer" => handle} = label) do
    Map.put(label, "url", "https://m.me/" <> handle)
  end

  defp process_label(%{"question" => "signal", "answer" => handle} = label) do
    Map.put(label, "url", "https://signal.me/#p/" <> handle)
  end

  defp process_label(%{"question" => "twitter", "answer" => handle} = label) do
    Map.put(label, "url", "https://twitter.com/" <> handle)
  end

  defp process_label(%{"question" => q} = label) when q in ["phone", "email"] do
    label
  end

  defp process_label(%{"answer" => a} = label) do
    if url = Media.known_sticker_url(a) do
      Map.put(label, "url", url)
    else
      label
    end
  end

  defp process_label(label), do: label

  defp s3_key_image_urls(key, width) when is_binary(key) do
    %{"proxy" => Media.user_imgproxy_cdn_url(key, width)}
  end
end
