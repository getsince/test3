defmodule TWeb.FeedChannel do
  use TWeb, :channel
  alias TWeb.ProfileView
  alias T.{Feeds, Accounts}

  @impl true
  def join("feed:" <> user_id, params, socket) do
    user_id = String.downcase(user_id)
    ChannelHelpers.verify_user_id(socket, user_id)

    # ChannelHelpers.ensure_onboarded(socket)

    %{screen_width: screen_width, current_user: current_user} = socket.assigns
    %Accounts.Profile{} = my_profile = Accounts.get_profile!(current_user)

    %{loaded: feed, next_ids: next_ids} =
      Feeds.batched_demo_feed(my_profile, loaded: params["count"] || 3)

    {:ok,
     %{
       feed: render_profiles(feed, screen_width),
       has_more: not Enum.empty?(next_ids),
       # TODO remove own profile
       own_profile: render_profile(my_profile, screen_width)
     }, assign(socket, profile: my_profile, next_ids: next_ids)}
  end

  @impl true
  # TODO possibly batch
  def handle_in("seen", %{"profile_id" => profile_id}, socket) do
    # TODO broadcast
    Feeds.mark_profile_seen(profile_id, by: socket.assigns.current_user.id)
    {:reply, :ok, socket}
  end

  # TODO test with timeout
  def handle_in("like", %{"profile_id" => profile_id} = params, socket) do
    # TODO verify_can_see_profile(socket, profile_id)
    user = socket.assigns.current_user

    if params["timeout?"] do
      Feeds.schedule_like_profile(user.id, profile_id)
    else
      Feeds.like_profile(user.id, profile_id)
    end

    {:reply, :ok, socket}
  end

  # TODO test
  def handle_in("cancel-like", %{"profile_id" => profile_id}, socket) do
    user = socket.assigns.current_user
    cancelled? = Feeds.cancel_like_profile(user.id, profile_id)
    {:reply, {:ok, %{cancelled: cancelled?}}, socket}
  end

  def handle_in("dislike", %{"profile_id" => profile_id}, socket) do
    Feeds.dislike_liker(profile_id, by: socket.assigns.current_user.id)
    {:reply, :ok, socket}
  end

  def handle_in("more", params, socket) do
    %{next_ids: next_ids, current_user: me, screen_width: screen_width} = socket.assigns

    %{loaded: feed, next_ids: next_ids} =
      Feeds.batched_demo_feed_cont(next_ids, me.id, loaded: params["count"] || 5)

    cursor = %{feed: render_profiles(feed, screen_width), has_more: not Enum.empty?(next_ids)}
    {:reply, {:ok, cursor}, assign(socket, next_ids: next_ids)}
  end

  def handle_in("report", %{"report" => report}, socket) do
    ChannelHelpers.report(socket, report)
  end

  #### MISC ####

  defp render_profile(profile, screen_width) do
    render(ProfileView, "feed_show.json", profile: profile, screen_width: screen_width)
  end

  defp render_profiles(profiles, screen_width) do
    Enum.map(profiles, &render_profile(&1, screen_width))
  end
end
