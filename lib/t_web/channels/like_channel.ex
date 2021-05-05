defmodule TWeb.LikeChannel do
  use TWeb, :channel
  alias T.{Feeds, Accounts}
  alias TWeb.ProfileView

  @impl true
  def join("likes:" <> user_id, _params, socket) do
    user_id = String.downcase(user_id)
    ChannelHelpers.verify_user_id(socket, user_id)

    Feeds.subscribe_for_likes(user_id)
    likers = Feeds.all_likers(user_id)

    {:ok, %{likers: render_profiles(likers)}, socket}
  end

  defp render_profiles(profiles) when is_list(profiles) do
    Enum.map(profiles, &render_profile/1)
  end

  defp render_profile(profile) do
    render(ProfileView, "feed_show.json", profile: profile)
  end

  @impl true
  # TODO possibly batch
  def handle_in("seen-like", %{"profile_id" => user_id}, socket) do
    Feeds.mark_liker_seen(user_id, by: socket.assigns.current_user.id)
    {:reply, :ok, socket}
  end

  @impl true
  def handle_info({Feeds, :liked, by_user_id}, socket) do
    liker = Accounts.get_profile!(by_user_id)
    push(socket, "liked", %{liker: render_profile(liker)})
    {:noreply, socket}
  end

  # def handle_info({Feeds, [:seen, :liker], liker_id}, socket) do
  #   push(socket, )
  # end
end
