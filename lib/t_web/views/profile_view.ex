defmodule TWeb.ProfileView do
  use TWeb, :view
  alias T.Accounts.Profile
  alias T.Media

  def render("show.json", %{profile: %Profile{} = profile}) do
    profile
    |> Map.take([
      :user_id,
      :photos,
      :song,
      :name,
      :gender,
      :birthdate,
      :height,
      :city,
      :occupation,
      :job,
      :university,
      :major,
      :most_important_in_life,
      :interests,
      :first_date_idea,
      :free_form,
      :tastes
    ])
    |> Map.update!(:photos, fn photos ->
      (photos || [])
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&s3_key_urls/1)
    end)
    |> Map.update!(:song, fn song ->
      if song, do: extract_song_info(song)
    end)
    |> Map.merge(%{story: render_story_from_profile(profile)})
  end

  defp extract_song_info(%{
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

  defp render_story_from_profile(%Profile{story: [_ | _] = story}) do
    postprocess_story(story)
  end

  defp render_story_from_profile(%Profile{} = profile) do
    %Profile{
      name: name,
      photos: photos,
      birthdate: birthdate,
      height: height,
      city: city,
      occupation: occupation,
      job: job,
      university: university,
      major: major,
      most_important_in_life: most_important_in_life,
      interests: interests,
      first_date_idea: first_date_idea,
      free_form: free_form,
      tastes: tastes
    } = profile

    bg_pages =
      (photos || [])
      |> Enum.reject(&is_nil/1)
      |> fill_bg_pages(4)

    labels =
      [
        if(name, do: %{"question" => "name", "answer" => name, "value" => name}),
        if(birthdate,
          do: %{"question" => "birthdate", "answer" => birthdate, "value" => birthdate}
        ),
        if(height, do: %{"question" => "height", "answer" => height, "value" => height}),
        if(city, do: %{"question" => "city", "answer" => city, "value" => city}),
        if(occupation,
          do: %{"question" => "occupation", "answer" => occupation, "value" => occupation}
        ),
        if(job, do: %{"question" => "job", "answer" => job, "value" => job}),
        if(university,
          do: %{"question" => "university", "answer" => university, "value" => university}
        ),
        if(major, do: %{"question" => "major", "answer" => major, "value" => major}),
        if(most_important_in_life,
          do: %{
            "question" => "most_important_in_life",
            "answer" => most_important_in_life,
            "value" => most_important_in_life
          }
        ),
        Enum.map(interests || [], fn interest ->
          %{"question" => "interests", "answer" => interest, "value" => interest}
        end),
        if(first_date_idea,
          do: %{
            "question" => "first_date_idea",
            "answer" => first_date_idea,
            "value" => first_date_idea
          }
        ),
        if(free_form, do: %{"value" => free_form}),
        Enum.map(tastes || %{}, fn {k, v} ->
          v = if is_list(v), do: Enum.join(v, ", "), else: v
          %{"question" => k, "answer" => v, "value" => v}
        end)
      ]
      |> List.flatten()
      |> Enum.reject(&is_nil/1)

    bg_pages_count = length(bg_pages)

    labels_per_page =
      if Enum.empty?(labels) do
        Enum.map(1..bg_pages_count, fn _ -> [] end)
      else
        approx_labels_count_per_page = ceil(length(labels) / bg_pages_count)

        labels
        |> Enum.map(fn label -> position_label(label) end)
        |> Enum.chunk_every(approx_labels_count_per_page)
      end

    story =
      [bg_pages, labels_per_page]
      |> Enum.zip()
      |> Enum.map(fn {bg, labels} -> Map.merge(bg, %{"labels" => labels}) end)

    postprocess_story(story)
  end

  if Mix.env() == :test do
    defp position_label(label) do
      Map.merge(%{"position" => [100, 100], "dimensions" => [400, 800]}, label)
    end
  else
    defp position_label(label) do
      x = :rand.uniform(400)
      y = :rand.uniform(800)
      Map.merge(%{"position" => [x, y], "dimensions" => [400, 800]}, label)
    end
  end

  defp fill_bg_pages(pages, min_count) when min_count > 0 do
    do_fill_bg_pages(pages, min_count)
  end

  defp fill_bg_pages(_photos, _min_count) do
    []
  end

  defp do_fill_bg_pages([], min_count) do
    Enum.map(1..min_count, fn _ -> color_page() end)
  end

  defp do_fill_bg_pages([photo], min_count) do
    [photo_page(photo)] ++ fill_bg_pages([], min_count - 1)
  end

  defp do_fill_bg_pages([p1, p2], min_count) do
    [photo_page(p1), color_page(), photo_page(p2)] ++ fill_bg_pages([], min_count - 3)
  end

  defp do_fill_bg_pages([p1, p2, p3], min_count) do
    [photo_page(p1), color_page(), photo_page(p2), photo_page(p3)] ++
      fill_bg_pages([], min_count - 4)
  end

  defp do_fill_bg_pages([_ | _] = photos, min_count) do
    pages =
      photos
      |> Enum.map(&photo_page/1)
      |> Enum.intersperse(:color)
      |> Enum.map(fn
        :color -> color_page()
        photo_page -> photo_page
      end)

    pages ++ fill_bg_pages([], min_count - length(pages))
  end

  defp photo_page(key) do
    %{"background" => %{"s3_key" => key}}
  end

  defp color_page(color \\ random_bg_color()) do
    %{"background" => %{"color" => color}}
  end

  if Mix.env() == :test do
    defp random_bg_color do
      "#E5E7EB"
    end
  else
    defp random_bg_color do
      Enum.random(["#E5E7EB", "#FCA5A5", "#FBBF24", "#6EE7B7", "#3B82F6", "#93C5FD", "#BE185D"])
    end
  end

  defp postprocess_story(story) when is_list(story) do
    Enum.map(story, fn
      %{"background" => %{"s3_key" => key} = bg} = page when not is_nil(key) ->
        bg = Map.merge(bg, s3_key_urls(key))
        %{page | "background" => bg}

      other_page ->
        other_page
    end)
  end

  defp s3_key_urls(key) when is_binary(key) do
    %{"s3" => Media.s3_url(key), "proxy" => Media.imgproxy_url(key)}
  end
end
