defmodule TWeb.ProfileChannel do
  use TWeb, :channel
  alias T.Accounts.Profile
  alias T.{Accounts, Music, Feeds}
  alias TWeb.{ErrorView, ProfileView}

  @impl true
  def join("profile:" <> user_id, _params, socket) do
    ChannelHelpers.verify_user_id(socket, user_id)
    %{screen_width: screen_width, current_user: current_user} = socket.assigns
    %Profile{} = profile = Accounts.get_profile!(current_user)

    {:ok, %{profile: render_profile(profile, screen_width)},
     assign(socket, uploads: %{}, profile: profile)}
  end

  defp render_profile(profile, screen_width) do
    render(ProfileView, "show_with_location.json", profile: profile, screen_width: screen_width)
  end

  defp render_onboarding_feed(profiles, screen_width) do
    Enum.map(profiles, fn profile ->
      render(ProfileView, "show.json", profile: profile, screen_width: screen_width)
    end)
  end

  defp render_editor_tutorial_story(story, screen_width) do
    render(ProfileView, "editor_tutorial_story.json", story: story, screen_width: screen_width)
  end

  @impl true
  def handle_in("upload-preflight", %{"media" => params}, socket) do
    "image/" <> _rest =
      content_type =
      case params do
        %{"content-type" => content_type} -> content_type
        %{"extension" => extension} -> MIME.type(extension)
      end

    {:ok, %{"key" => key} = fields} = Accounts.photo_upload_form(content_type)
    url = Accounts.photo_s3_url()

    uploads = socket.assigns.uploads
    socket = assign(socket, uploads: Map.put(uploads, key, nil))

    # TODO check key afterwards
    {:reply, {:ok, %{url: url, key: key, fields: fields}}, socket}
  end

  def handle_in("get-me", _params, socket) do
    %{screen_width: screen_width, current_user: current_user} = socket.assigns
    %Profile{} = profile = Accounts.get_profile!(current_user)

    {:reply, {:ok, %{profile: render_profile(profile, screen_width)}},
     assign(socket, profile: profile)}
  end

  # TODO refresh after two hours
  def handle_in("get-music-token", _params, socket) do
    token = socket.assigns[:music_token] || Music.token()
    socket = assign(socket, music_token: token)
    {:reply, {:ok, %{token: token}}, socket}
  end

  def handle_in("known-stickers", _params, socket) do
    {:reply, {:ok, %{stickers: T.Media.known_stickers()}}, socket}
  end

  def handle_in("submit", %{"profile" => params}, socket) do
    %{profile: profile, current_user: user, screen_width: screen_width} = socket.assigns
    params = params |> with_song() |> replace_story_photo_urls_with_s3keys()

    # TODO check photos exist in s3
    f =
      if Accounts.user_onboarded?(user.id) do
        fn -> Accounts.update_profile(profile, params) end
      else
        fn -> Accounts.onboard_profile(profile, params) end
      end

    case f.() do
      {:ok, profile} ->
        {:reply, {:ok, %{profile: render_profile(profile, screen_width)}},
         assign(socket, profile: profile)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:reply, {:error, %{profile: render(ErrorView, "changeset.json", changeset: changeset)}},
         socket}
    end
  end

  # TODO test
  def handle_in("delete-account", _payload, socket) do
    %{current_user: user} = socket.assigns
    {:ok, %{session_tokens: tokens}} = Accounts.delete_user(user.id)

    for token <- tokens do
      encoded = Accounts.UserToken.encoded_token(token)
      TWeb.Endpoint.broadcast("user_socket:#{encoded}", "disconnect", %{})
    end

    {:reply, :ok, socket}
  end

  def handle_in("onboarding-feed", _payload, socket) do
    %{screen_width: screen_width} = socket.assigns
    feed = Feeds.onboarding_feed()
    {:reply, {:ok, %{feed: render_onboarding_feed(feed, screen_width)}}, socket}
  end

  def handle_in("profile-editor-tutorial", params, socket) do
    %{screen_width: screen_width} = socket.assigns
    id = params["id"] || "yabloko"
    story = Accounts.profile_editor_tutorial(id)
    {:reply, {:ok, %{story: render_editor_tutorial_story(story, screen_width)}}, socket}
  end

  defp with_song(%{"song" => none} = params) when none in [nil, ""] do
    Map.put(params, "song", nil)
  end

  defp with_song(%{"song" => song_id} = params) do
    Map.put(params, "song", Music.get_song(song_id))
  end

  defp with_song(params), do: params

  defp replace_story_photo_urls_with_s3keys(%{"story" => story} = params) do
    story =
      Enum.map(story, fn %{"background" => background} = page ->
        %{page | "background" => replace_photo_url_with_s3key(background)}
      end)

    Map.put(params, "story", story)
  end

  defp replace_story_photo_urls_with_s3keys(params), do: params

  defp replace_photo_url_with_s3key(%{"s3_key" => _} = background), do: background
  defp replace_photo_url_with_s3key(%{"color" => _} = bg), do: bg

  defp replace_photo_url_with_s3key(%{"proxy" => proxy_url}) do
    %{"s3_key" => s3_key_from_proxy_url(proxy_url)}
  end

  defp s3_key_from_proxy_url("https://d1l2m9fv9eekdw.cloudfront.net/" <> path) do
    "https://of-course-i-still-love-you.s3.amazonaws.com/" <> s3_key =
      path |> String.split("/") |> List.last() |> Base.decode64!(padding: false)

    s3_key
  end
end
