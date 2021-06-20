defmodule TWeb.LikeChannel do
  use TWeb, :channel

  alias T.Feeds
  alias TWeb.ProfileView

  @impl true
  def join("likes:" <> user_id, %{"version" => 2 = version}, socket) do
    user_id = verify_and_normalize_user_id(socket, user_id)

    socket = assign(socket, version: version)
    Feeds.subscribe_for_likes(user_id)
    screen_width = socket.assigns.screen_width

    likes = Feeds.all_profile_likes_with_liker_profile(user_id)
    {:ok, %{likes: render_likes(likes, screen_width), version: version}, socket}
  end

  def join("likes:" <> user_id, _params, socket) do
    user_id = verify_and_normalize_user_id(socket, user_id)

    version = 1
    socket = assign(socket, version: version)
    Feeds.subscribe_for_likes(user_id)
    screen_width = socket.assigns.screen_width

    likers = Feeds.all_likers(user_id)
    {:ok, %{likers: render_profiles(likers, screen_width), version: version}, socket}
  end

  defp verify_and_normalize_user_id(socket, user_id) do
    user_id = String.downcase(user_id)
    ChannelHelpers.verify_user_id(socket, user_id)
    user_id
  end

  defp render_profiles(profiles, screen_width) when is_list(profiles) do
    Enum.map(profiles, &render_profile(&1, screen_width))
  end

  defp render_profile(profile, screen_width) do
    render(ProfileView, "feed_show.json", profile: profile, screen_width: screen_width)
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
    Feeds.mark_liker_seen(user_id, by: socket.assigns.current_user.id)
    {:reply, :ok, socket}
  end

  @impl true
  def handle_info({Feeds, :liked, %Feeds.ProfileLike{} = like}, socket) do
    like = Feeds.preload_liker_profile(like)
    screen_width = socket.assigns.screen_width
    push(socket, "liked", %{like: render_like(like, screen_width)})
    {:noreply, socket}
  end

  # def handle_info({Feeds, [:seen, :liker], liker_id}, socket) do
  #   push(socket, )
  # end
end
