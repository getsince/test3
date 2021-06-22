defmodule TWeb.ProfileView do
  use TWeb, :view
  alias T.Accounts.Profile
  alias T.Feeds.ProfileLike
  alias T.Media

  def render("show.json", %{profile: %Profile{} = profile, screen_width: screen_width}) do
    render_profile(profile, [:user_id, :song, :name, :gender], screen_width)
  end

  def render("show_with_location.json", %{
        profile: %Profile{location: location, filters: filters} = profile,
        screen_width: screen_width
      }) do
    profile
    |> render_profile([:user_id, :song, :name, :gender], screen_width)
    |> Map.put(:latitude, lat(location))
    |> Map.put(:longitude, lon(location))
    |> Map.put(:gender_preference, genders(filters))
  end

  def render("like.json", %{like: like, screen_width: screen_width}) do
    %ProfileLike{
      seen?: seen?,
      inserted_at: inserted_at,
      liker_profile: %Profile{} = liker_profile
    } = like

    %{
      seen?: !!seen?,
      inserted_at: DateTime.from_naive!(inserted_at, "Etc/UTC"),
      profile: render_profile(liker_profile, [:user_id, :song, :name, :gender], screen_width)
    }
  end

  defp lat(%Geo.Point{coordinates: {_lon, lat}}), do: lat
  defp lat(nil), do: nil

  defp lon(%Geo.Point{coordinates: {lon, _lat}}), do: lon
  defp lon(nil), do: nil

  defp genders(%Profile.Filters{genders: genders}), do: genders
  defp genders(nil), do: nil

  defp render_profile(profile, fields, screen_width) do
    profile
    |> Map.take(fields)
    |> Map.update!(:song, fn song ->
      if song, do: extract_song_info(song)
    end)
    |> Map.merge(%{story: render_story_from_profile(profile, screen_width)})
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

  defp render_story_from_profile(%Profile{story: [_ | _] = story}, screen_width) do
    postprocess_story(story, screen_width)
  end

  defp render_story_from_profile(%Profile{} = profile, screen_width) do
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
        if(name,
          do: %{"question" => "name", "answer" => name, "value" => name}
        ),
        if(birthdate,
          do: %{"question" => "birthdate", "answer" => birthdate, "value" => age(birthdate)}
        ),
        if(height,
          do: %{"question" => "height", "answer" => height, "value" => to_string(height) <> "см"}
        ),
        if(city,
          do: %{"question" => "city", "answer" => city, "value" => city}
        ),
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
          v
          |> List.wrap()
          |> Enum.map(fn taste ->
            %{
              "question" => k,
              "answer" => taste,
              "value" => taste
            }
          end)
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
        |> Enum.chunk_every(approx_labels_count_per_page)
        |> Enum.map(&position_labels/1)
      end

    story =
      [bg_pages, labels_per_page]
      |> Enum.zip()
      |> Enum.map(fn {bg, labels} ->
        Map.merge(bg, %{"size" => [400, 800], "labels" => labels})
      end)

    postprocess_story(story, screen_width)
  end

  defp age(date) do
    to_string(calc_diff(date, Date.utc_today()))
  end

  defp calc_diff(%Date{year: y1, month: m1, day: d1}, %Date{year: y2, month: m2, day: d2})
       when m2 > m1 or (m2 == m1 and d2 >= d1) do
    y2 - y1
  end

  defp calc_diff(%Date{year: y1}, %Date{year: y2}), do: y2 - y1 - 1

  if Mix.env() == :test do
    defp position_label(label, _width, _height, _x, _y) do
      Map.merge(%{"center" => [100, 100], "size" => [100, 100]}, label)
    end
  else
    defp position_label(label, width, height, x, y) do
      Map.merge(
        %{
          "position" => [x, y],
          "center" => [x, y],
          "dimensions" => [400, 800],
          "size" => [width, height],
          "rotation" => 30 - :rand.uniform(60)
        },
        label
      )
    end
  end

  defp position_labels(labels) do
    position_labels(labels, _prev_width = 0, _prev_hight = 225)
  end

  defp position_labels([label | rest], prev_width, prev_height) do
    width = 80 + :rand.uniform(50)
    height = 50 + :rand.uniform(80)

    {x, y} =
      if prev_width + width >= 400 do
        # move to next row
        {width / 2 + 10, prev_height + 30 + height / 2}
      else
        # move to next column
        {prev_width + width / 2 + 10, prev_height - 75 + height / 2}
      end

    [
      position_label(label, width, height, x, y)
      | position_labels(rest, x + width / 2, y + height / 2)
    ]
  end

  defp position_labels([], _prev_width, _prev_height), do: []

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
    since_pink = "#" <> Base.encode16(<<249, 126, 172>>)
    since_blue = "#" <> Base.encode16(<<74, 92, 235>>)
    since_green = "#" <> Base.encode16(<<9, 186, 111>>)
    since_red = "#" <> Base.encode16(<<219, 59, 47>>)
    since_gray = "#" <> Base.encode16(<<96, 96, 96>>)
    colors = [since_pink, since_blue, since_green, since_red, since_gray]

    defp random_bg_color do
      Enum.random(unquote(colors))
    end
  end

  defp postprocess_story(story, screen_width) when is_list(story) do
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
