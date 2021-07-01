defmodule TWeb.LikeChannel do
  use TWeb, :channel
  import TWeb.ChannelHelpers

  alias T.Feeds
  alias TWeb.ProfileView

  @impl true
  def join("likes:" <> user_id, %{"version" => 2 = version}, socket) do
    user_id = verify_user_id(socket, user_id)

    socket = assign(socket, version: version)
    Feeds.subscribe_for_likes(user_id)
    screen_width = socket.assigns.screen_width

    likes = Feeds.all_profile_likes_with_liker_profile(user_id)
    {:ok, %{likes: render_likes(likes, screen_width), version: version}, socket}
  end

  defp render_likes(likes, screen_width) when is_list(likes) do
    Enum.map(likes, &render_like(&1, screen_width))
  end

  defp render_like(like, screen_width) do
    render(ProfileView, "like.json", like: like, screen_width: screen_width)
  end

  @impl true
  # TODO possibly batch
  def handle_in("seen-like", %{"profile_id" => user_id}, socket) do
    Feeds.mark_liker_seen(user_id, by: current_user(socket).id)
    {:reply, :ok, socket}
  end

  @impl true
  def handle_info({Feeds, :liked, %Feeds.ProfileLike{} = like}, socket) do
    like = Feeds.preload_liker_profile(like)
    screen_width = socket.assigns.screen_width
    push(socket, "liked", %{like: render_like(like, screen_width)})
    {:noreply, socket}
  end
end
