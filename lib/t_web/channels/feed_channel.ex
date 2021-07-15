defmodule TWeb.FeedChannel do
  use TWeb, :channel
  import TWeb.ChannelHelpers
  alias TWeb.ProfileView
  alias T.{Feeds, Accounts}

  @impl true
  def join("feed:" <> user_id, params, socket) do
    user_id = verify_user_id(socket, user_id)
    continue_join(user_id, params, socket)
  end

  # apple
  defp continue_join("0000017a-a0f0-c00e-0242-ac1100040000" = user_id, _params, socket) do
    %{screen_width: screen_width, current_user: current_user} = socket.assigns

    my_profile = Accounts.get_profile!(current_user)
    socket = assign(socket, profile: my_profile)

    feed = Feeds.yabloko_feed(user_id)
    socket = assign(socket, next_ids: [])
    {:ok, %{feed: render_profiles(feed, screen_width)}, socket}
  end

  # everyone else
  defp continue_join(_user_id, params, socket) do
    %{screen_width: screen_width, current_user: current_user} = socket.assigns
    profiles_to_load = params["count"] || 3

    %Accounts.Profile{gender: gender} = my_profile = Accounts.get_profile!(current_user)
    socket = assign(socket, profile: my_profile)

    if gender do
      %{loaded: feed, next_ids: next_ids} =
        Feeds.init_batched_feed(my_profile, loaded: profiles_to_load)

      socket = assign(socket, next_ids: next_ids)
      {:ok, %{feed: render_profiles(feed, screen_width)}, socket}
    else
      {:ok, %{feed: []}, socket}
    end
  end

  @impl true
  # TODO possibly batch
  def handle_in("seen", %{"profile_id" => profile_id}, socket) do
    # TODO broadcast
    Feeds.mark_profile_seen(profile_id, by: current_user(socket).id)
    {:reply, :ok, socket}
  end

  # TODO test with timeout
  def handle_in("like", %{"profile_id" => profile_id} = params, socket) do
    # TODO verify_can_see_profile(socket, profile_id)
    user = current_user(socket)

    if params["timeout?"] do
      Feeds.schedule_like_profile(user.id, profile_id)
    else
      Feeds.like_profile(user.id, profile_id)
    end

    {:reply, :ok, socket}
  end

  # TODO test
  def handle_in("cancel-like", %{"profile_id" => profile_id}, socket) do
    cancelled? = Feeds.cancel_like_profile(current_user(socket).id, profile_id)
    {:reply, {:ok, %{cancelled: cancelled?}}, socket}
  end

  def handle_in("dislike", %{"profile_id" => profile_id}, socket) do
    Feeds.dislike_liker(profile_id, by: current_user(socket).id)
    {:reply, :ok, socket}
  end

  # TODO when user changes profile settings, refresh profile in memory
  # otherwise we might continue fetching wrong feed
  def handle_in("more", params, socket) do
    profiles_to_load = params["count"] || 3

    case next_ids(socket) do
      [] -> stop_feed(socket)
      _not_empty -> continue_feed(socket, profiles_to_load)
    end
  end

  def handle_in("report", %{"report" => report}, socket) do
    ChannelHelpers.report(socket, report)
  end

  def handle_in("onboarding-feed", _params, socket) do
    %{screen_width: screen_width} = socket.assigns
    feed = T.Feeds.onboarding_feed()
    {:reply, {:ok, %{feed: render_profiles(feed, screen_width)}}, socket}
  end

  #### MISC ####

  defp stop_feed(socket) do
    {:reply, {:ok, _cursor = %{feed: [], has_more: false}}, socket}
  end

  defp continue_feed(socket, profiles_to_load) do
    %{profile: my_profile, screen_width: screen_width, next_ids: next_ids} = socket.assigns

    %{loaded: feed, next_ids: next_ids} =
      Feeds.continue_batched_feed(next_ids, my_profile, loaded: profiles_to_load)

    cursor = %{feed: render_profiles(feed, screen_width), has_more: not Enum.empty?(next_ids)}
    {:reply, {:ok, cursor}, assign(socket, next_ids: next_ids)}
  end

  defp next_ids(socket) do
    socket.assigns.next_ids
  end

  defp render_profile(profile, screen_width) do
    render(ProfileView, "show.json", profile: profile, screen_width: screen_width)
  end

  defp render_profiles(profiles, screen_width) do
    Enum.map(profiles, &render_profile(&1, screen_width))
  end
end
