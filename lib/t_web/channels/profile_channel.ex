defmodule TWeb.ProfileChannel do
  use TWeb, :channel
  alias T.Accounts.Profile
  alias T.Accounts
  alias TWeb.{ErrorView, ProfileView}

  @impl true
  def join("profile:" <> user_id, _params, socket) do
    if ChannelHelpers.valid_user_topic?(socket, user_id) do
      %{screen_width: screen_width, version: version, current_user: current_user} = socket.assigns
      %Profile{} = profile = Accounts.get_profile!(current_user)

      {:ok,
       %{
         profile: render_profile(profile, version, screen_width),
         stickers: T.Media.known_stickers(),
         min_version: 1
       }, assign(socket, uploads: %{}, profile: profile)}
    else
      {:error, %{"error" => "forbidden"}}
    end
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
    %{screen_width: screen_width, version: version, current_user: current_user} = socket.assigns
    %Profile{} = profile = Accounts.get_profile!(current_user)

    {:reply, {:ok, %{profile: render_profile(profile, version, screen_width)}},
     assign(socket, profile: profile)}
  end

  def handle_in("known-stickers", _params, socket) do
    {:reply, {:ok, %{stickers: T.Media.known_stickers()}}, socket}
  end

  def handle_in("submit", %{"profile" => params}, socket) do
    %{profile: profile, current_user: user, version: version, screen_width: screen_width} =
      socket.assigns

    params = params |> replace_story_photo_urls_with_s3keys()

    # TODO check photos exist in s3
    f =
      if Accounts.user_onboarded?(user.id) do
        fn -> Accounts.update_profile(profile, params) end
      else
        fn -> Accounts.onboard_profile(profile, params) end
      end

    case f.() do
      {:ok, profile} ->
        {:reply, {:ok, %{profile: render_profile(profile, version, screen_width)}},
         assign(socket, profile: profile)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:reply, {:error, %{profile: render(ErrorView, "changeset.json", changeset: changeset)}},
         socket}
    end
  end

  def handle_in("profile-editor-tutorial", params, socket) do
    %{screen_width: screen_width, version: version} = socket.assigns
    id = params["id"] || "yabloko"
    story = Accounts.profile_editor_tutorial(id)
    {:reply, {:ok, %{story: render_editor_tutorial_story(story, version, screen_width)}}, socket}
  end

  defp replace_story_photo_urls_with_s3keys(%{"story" => story} = params) do
    story =
      Enum.map(story, fn page ->
        page
        |> maybe_replace_url_with_s3key_for_key("background")
        |> maybe_replace_url_with_s3key_for_key("blurred")
      end)

    Map.put(params, "story", story)
  end

  defp replace_story_photo_urls_with_s3keys(params), do: params

  defp maybe_replace_url_with_s3key_for_key(page, key) do
    if value = Map.get(page, key) do
      Map.put(page, key, replace_photo_url_with_s3key(value))
    else
      page
    end
  end

  defp replace_photo_url_with_s3key(%{"s3_key" => _} = background), do: background
  defp replace_photo_url_with_s3key(%{"color" => _} = bg), do: bg

  defp replace_photo_url_with_s3key(%{"proxy" => proxy_url}) do
    %{"s3_key" => s3_key_from_proxy_url(proxy_url)}
  end

  # TODO fix, client shouldn't be sending urls
  defp s3_key_from_proxy_url("https://d3r9yicn85nax9.cloudfront.net/" <> path) do
    "https://since-when-are-you-happy.s3.amazonaws.com/" <> s3_key =
      path |> String.split("/") |> List.last() |> Base.decode64!(padding: false)

    s3_key
  end

  defp render_profile(profile, version, screen_width) do
    render(ProfileView, "show_with_location.json",
      profile: profile,
      screen_width: screen_width,
      version: version
    )
  end

  defp render_editor_tutorial_story(story, version, screen_width) do
    render(ProfileView, "editor_tutorial_story.json",
      story: story,
      screen_width: screen_width,
      version: version
    )
  end
end
