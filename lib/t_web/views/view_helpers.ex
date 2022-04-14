defmodule TWeb.ViewHelpers do
  @moduledoc false
  alias T.Media
  alias T.Accounts
  alias T.Accounts.Profile

  @type env :: :feed | :match | :profile

  @spec postprocess_story([map], String.t(), pos_integer(), env) :: [map]
  def postprocess_story(story, "6." <> _rest = version, screen_width, env) when is_list(story) do
    Enum.map(story, fn page ->
      page
      |> blur(screen_width, env)
      |> add_bg_url(screen_width)
      |> process_labels_v6(version)
    end)
  end

  def postprocess_story(story, _version, screen_width, _env) when is_list(story) do
    story
    |> Enum.reduce([], fn
      # users on version < 6.0.0 don't support private pages
      %{"blurred" => _} = _private_page, acc ->
        acc

      page, acc ->
        rendered =
          page
          |> add_bg_url(screen_width)
          |> process_labels_pre_v6()

        [rendered | acc]
    end)
    |> :lists.reverse()
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

  defp process_labels_v6(%{"labels" => labels} = page, version) do
    labels =
      labels
      |> Enum.reduce([], fn label, acc ->
        # if the label is a text contact, it's removed from page
        # since it has been replaced with contact stickers
        if Map.has_key?(label, "text-contact") do
          acc
        else
          case label do
            %{"s3_key" => key, "question" => "audio"} ->
              # we do not add url for versions prior to 6.2.0 because they will be rendered incorrectly
              case Version.compare(version, "6.2.0") do
                :lt ->
                  acc

                _ ->
                  label = Map.put(label, "url", Accounts.voice_url(key))
                  [label | acc]
              end

            label ->
              [process_label(label) | acc]
          end
        end
      end)
      |> :lists.reverse()

    %{page | "labels" => labels}
  end

  defp process_labels_v6(page, _version), do: page

  defp process_labels_pre_v6(%{"labels" => labels} = page) do
    labels =
      labels
      |> Enum.reduce([], fn label, acc ->
        # users on version < 6.0.0 don't support contact stickers, so they are removed
        if Map.get(label, "question") in Profile.contacts() or Map.get(label, "text-change") do
          acc
        else
          label = label |> process_label() |> Map.delete("text-contact")
          [label | acc]
        end
      end)
      |> :lists.reverse()

    %{page | "labels" => labels}
  end

  defp process_labels_pre_v6(page), do: page

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
