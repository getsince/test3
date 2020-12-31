defmodule TWeb.FeedChannel do
  use TWeb, :channel
  alias TWeb.FeedView
  alias T.Feed

  @impl true
  def join("feed:" <> user_id, _params, socket) do
    ChannelHelpers.verify_user_id(socket, user_id)
    ChannelHelpers.ensure_onboarded(socket)

    feed = Feed.get_feed(user_id)
    :ok = Feed.subscribe_to_matched()

    # TODO show who's online

    {:ok, %{feed: render_many(feed, FeedView, "profile-preview.json")},
     assign(socket, visible_ids: visible_ids(feed))}
  end

  @impl true
  def handle_in("show", %{"profile_id" => profile_id}, socket) do
    verify_can_see_profile(socket, profile_id)
    profile = Feed.get_profile(profile_id)
    {:reply, {:ok, %{profile: render(FeedView, "profile.json", profile: profile)}}, socket}
  end

  def handle_in("like", %{"profile_id" => profile_id}, socket) do
    verify_can_see_profile(socket, profile_id)
    match? = Feed.like_profile(socket.assigns.current_user, profile_id)
    {:reply, {:ok, %{match?: match?}}, socket}
  end

  @impl true
  def handle_info({Feed, :matched, [user_id_1, user_id_2] = user_ids}, socket) do
    current_user = socket.assigns.current_user
    me? = current_user.id in user_ids

    socket =
      if me? do
        [not_me] = user_ids -- [current_user.id]
        push(socket, "match", %{"profile_id" => not_me})
        socket
      else
        visible_ids = socket.assigns.visible_ids
        one_of_mine? = user_id_1 in visible_ids or user_id_2 in visible_ids

        if one_of_mine? do
          feed = Feed.force_update_feed(socket.assigns.current_user)

          push(socket, "update-feed", %{
            "feed" => render_many(feed, FeedView, "profile-preview.json")
          })

          assign(socket, visible_ids: visible_ids(feed))
        else
          socket
        end
      end

    {:noreply, socket}
  end

  defp visible_ids(feed) do
    Enum.map(feed, & &1.user_id)
  end

  defp verify_can_see_profile(socket, profile_id) do
    visible_ids = socket.assigns.visible_ids
    true = profile_id in visible_ids
  end
end
