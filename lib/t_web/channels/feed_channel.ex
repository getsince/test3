defmodule TWeb.FeedChannel do
  use TWeb, :channel
  alias TWeb.ProfileView
  alias T.{Feeds, Matches, Accounts}

  @impl true
  def join("feed:" <> user_id, _params, socket) do
    ChannelHelpers.verify_user_id(socket, user_id)
    # ChannelHelpers.ensure_onboarded(socket)

    :ok = Feeds.subscribe(user_id)

    # TODO show who's online

    # TODO schedule feed refresh

    if match = Matches.get_current_match(user_id) do
      other_profile = Matches.get_other_profile_for_match!(match, user_id)
      {:ok, %{match: render_match(match, other_profile)}, socket}
    else
      my_profile = Accounts.get_profile!(socket.assigns.current_user)
      feed = Feeds.get_or_create_feed(my_profile)
      {:ok, %{feed: render_profiles(feed)}, socket}
    end
  end

  defp render_match(match, profile) do
    %{
      id: match.id,
      profile: render_profile(profile)
    }
  end

  defp render_profile(profile) do
    render(ProfileView, "show.json", profile: profile)
  end

  defp render_profiles(profiles) do
    Enum.map(profiles, &render_profile/1)
  end

  @impl true
  def handle_in("like", %{"profile_id" => profile_id}, socket) do
    # verify_can_see_profile(socket, profile_id)
    user = socket.assigns.current_user
    {:ok, _} = Feeds.like_profile(user.id, profile_id)
    {:reply, :ok, socket}
  end

  def handle_in("dislike", %{"profile_id" => profile_id}, socket) do
    user = socket.assigns.current_user
    :ok = Feeds.dislike_profile(user.id, profile_id)
    {:reply, :ok, socket}
  end

  # TODO test
  def handle_in(
        "report",
        %{"report" => %{"reason" => reason, "profile_id" => reported_user_id}},
        socket
      ) do
    %{current_user: reporter} = socket.assigns

    case Accounts.report_user(reporter.id, reported_user_id, reason) do
      :ok ->
        {:reply, :ok, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:reply, {:error, %{report: render(ErrorView, "changeset.json", changeset: changeset)}},
         socket}
    end
  end

  # TODO fetch feed

  @impl true
  def handle_info({Feeds, [:matched], match}, socket) do
    other_profile = Matches.get_other_profile_for_match!(match, socket.assigns.current_user.id)
    push(socket, "matched", %{match: render_match(match, other_profile)})
    {:noreply, socket}
  end

  # TODO test
  def handle_info({Matches, [:pending_match_activated], match}, socket) do
    other_profile = Matches.get_other_profile_for_match!(match, socket.assigns.current_user.id)
    push(socket, "matched", %{match: render_match(match, other_profile)})
    {:noreply, socket}
  end
end
