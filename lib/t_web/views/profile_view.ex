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
      |> Enum.map(fn key -> %{"s3" => Media.s3_url(key), "proxy" => Media.imgproxy_url(key)} end)
    end)
    |> Map.update!(:song, fn song ->
      if song, do: extract_song_info(song)
    end)
  end

  defp extract_song_info(%{
         "data" => [
           %{
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
      "artist_name" => artist_name,
      "album_cover" => album_cover,
      "song_name" => song_name,
      "preview_url" => preview_url
    }
  end
end
