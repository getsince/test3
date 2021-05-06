defmodule TWeb.FeedChannel do
  use TWeb, :channel
  alias TWeb.ProfileView
  alias T.{Feeds, Accounts}

  @impl true
  def join("feed:" <> user_id, params, socket) do
    user_id = String.downcase(user_id)
    ChannelHelpers.verify_user_id(socket, user_id)

    # ChannelHelpers.ensure_onboarded(socket)

    %Accounts.Profile{} = my_profile = Accounts.get_profile!(socket.assigns.current_user)

    # TODO remove check for batched
    if params["batched"] do
      %{loaded: feed, next_ids: next_ids} =
        Feeds.batched_demo_feed(my_profile, loaded: params["count"] || 3)

      {:ok,
       %{
         feed: render_profiles(feed),
         has_more: not Enum.empty?(next_ids),
         # TODO remove own profile
         own_profile: render_profile(my_profile)
       }, assign(socket, profile: my_profile, next_ids: next_ids)}
    else
      feed = Feeds.demo_feed(my_profile)
      {:ok, %{feed: render_profiles(feed), own_profile: render_profile(my_profile)}, socket}
    end
  end

  @impl true
  # TODO possibly batch
  def handle_in("seen", %{"profile_id" => profile_id}, socket) do
    # TODO broadcast
    Feeds.mark_profile_seen(profile_id, by: socket.assigns.current_user.id)
    {:reply, :ok, socket}
  end

  def handle_in("like", %{"profile_id" => profile_id}, socket) do
    # TODO verify_can_see_profile(socket, profile_id)
    user = socket.assigns.current_user
    Feeds.like_profile(user.id, profile_id)
    {:reply, :ok, socket}
  end

  def handle_in("dislike", %{"profile_id" => profile_id}, socket) do
    Feeds.dislike_liker(profile_id, by: socket.assigns.current_user.id)
    {:reply, :ok, socket}
  end

  def handle_in("more", params, socket) do
    %{next_ids: next_ids, current_user: me} = socket.assigns

    %{loaded: feed, next_ids: next_ids} =
      Feeds.batched_demo_feed_cont(next_ids, me.id, loaded: params["count"] || 5)

    cursor = %{feed: render_profiles(feed), has_more: not Enum.empty?(next_ids)}
    {:reply, {:ok, cursor}, assign(socket, next_ids: next_ids)}
  end

  def handle_in("report", %{"report" => report}, socket) do
    ChannelHelpers.report(socket, report)
  end

  #### MISC ####

  defp render_profile(profile) do
    render(ProfileView, "feed_show.json", profile: profile)
  end

  defp render_profiles(profiles) do
    Enum.map(profiles, &render_profile/1)
  end
end
