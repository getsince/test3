defmodule TWeb.ProfileChannel do
  use TWeb, :channel
  alias T.Accounts.Profile
  alias T.{Accounts, Media, Spotify}
  alias TWeb.{ErrorView, ProfileView}

  @impl true
  def join("profile:" <> user_id, _params, socket) do
    if ChannelHelpers.valid_user_topic?(socket, user_id) do
      %{screen_width: screen_width, version: version, current_user: current_user} = socket.assigns
      %Profile{} = profile = Accounts.get_profile!(current_user)

      reply = %{
        profile: render_profile(profile, version, screen_width),
        stickers: T.Media.known_stickers(),
        min_version: 1
      }

      {:ok, reply, socket}
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

    {:reply, {:ok, %{url: url, key: key, fields: fields}}, socket}
  end

  def handle_in("get-me", _params, socket) do
    %{screen_width: screen_width, version: version, current_user: current_user} = socket.assigns
    %Profile{} = profile = Accounts.get_profile!(current_user)
    reply = %{profile: render_profile(profile, version, screen_width)}
    {:reply, {:ok, reply}, socket}
  end

  def handle_in("known-stickers", _params, socket) do
    {:reply, {:ok, %{stickers: Media.known_stickers()}}, socket}
  end

  def handle_in("submit", %{"profile" => params}, socket) do
    %{current_user: %{id: user_id}, version: version, screen_width: screen_width} = socket.assigns

    # TODO check photos exist in s3
    f =
      if Accounts.user_onboarded?(user_id) do
        fn -> Accounts.update_profile(user_id, params) end
      else
        fn -> Accounts.onboard_profile(user_id, params) end
      end

    reply =
      case f.() do
        {:ok, profile} ->
          {:ok, %{profile: render_profile(profile, version, screen_width)}}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:error, %{profile: render(ErrorView, "changeset.json", changeset: changeset)}}
      end

    {:reply, reply, socket}
  end

  def handle_in("get-spotify-token", _params, %{} = socket) do
    {:reply, Spotify.current_token(), socket}
  end

  def handle_in("update-address", address, socket) do
    %{current_user: %{id: user_id}} = socket.assigns
    {:reply, Accounts.update_address(user_id, address), socket}
  end

  defp render_profile(profile, version, screen_width) do
    render(ProfileView, "show_with_location.json",
      profile: profile,
      screen_width: screen_width,
      version: version
    )
  end
end
