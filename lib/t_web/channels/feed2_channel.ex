defmodule TWeb.Feed2Channel do
  use TWeb, :channel

  alias TWeb.ChannelHelpers
  alias T.Feeds.{FeedProfile, ActiveSession}
  alias T.{Feeds2, Calls}

  # TODO presence per active user

  @impl true
  def join("feed2:" <> user_id, _params, socket) do
    user_id = ChannelHelpers.verify_user_id(socket, user_id)

    :ok = Feeds2.subscribe_for_invites(user_id)
    :ok = Feeds2.subscribe_for_activated_sessions()
    :ok = Feeds2.subscribe_for_deactivated_sessions()

    current_session =
      if session = Feeds2.get_current_session(user_id) do
        render_session(session)
      end

    {:ok, %{"current_session" => current_session}, socket}
  end

  @impl true
  def handle_in("more", params, socket) do
    %{current_user: user, screen_width: screen_width} = socket.assigns
    {feed, cursor} = Feeds2.fetch_feed(user.id, params["count"] || 10, params["cursor"])
    {:reply, {:ok, %{"feed" => render_feed(feed, screen_width), "cursor" => cursor}}, socket}
  end

  # TODO accept cursor?
  def handle_in("invites", _params, socket) do
    %{current_user: user, screen_width: screen_width} = socket.assigns
    invites = Feeds2.list_received_invites(user.id)
    {:reply, {:ok, %{"invites" => render_feed(invites, screen_width)}}, socket}
  end

  def handle_in("invite", %{"user_id" => user_id}, socket) do
    invited? = Feeds2.invite_active_user(socket.assigns.current_user.id, user_id)
    {:reply, {:ok, %{"invited" => invited?}}, socket}
  end

  def handle_in("call", %{"user_id" => called}, socket) do
    caller = socket.assgins.current_user.id

    reply =
      case Calls.call(caller, called) do
        {:ok, call_id} -> {:ok, %{"call_id" => call_id}}
        {:error, reason} -> {:error, %{"reason" => reason}}
      end

    {:reply, reply, socket}
  end

  def handle_in("activate-session", %{"duration" => duration}, socket) do
    %{current_user: user} = socket.assigns
    Feeds2.activate_session(user.id, duration)
    {:reply, :ok, socket}
  end

  # TODO test
  def handle_in("deactivate-session", _params, socket) do
    %{current_user: user} = socket.assigns
    deactivated? = Feeds2.deactivate_session(user.id)
    {:reply, {:ok, %{"deactivated" => deactivated?}}, socket}
  end

  def handle_in("report", %{"report" => report}, socket) do
    ChannelHelpers.report(socket, report)
  end

  @impl true
  def handle_info({Feeds2, :invited, by_user_id}, socket) do
    %{current_user: user, screen_width: screen_width} = socket.assigns

    if feed_item = Feeds2.get_feed_item(user.id, by_user_id) do
      push(socket, "invite", %{
        "feed_item" => render_feed_item(feed_item, screen_width)
      })
    end

    {:noreply, socket}
  end

  # TODO test
  # TODO optimise pubsub, and use fastlane (one encode per screen width) or move screen width logic to the client
  def handle_info({Feeds2, :activated, user_id}, socket) do
    %{current_user: user, screen_width: screen_width} = socket.assigns

    if feed_item = Feeds2.get_feed_item(user.id, user_id) do
      push(socket, "activated", %{
        "feed_item" => render_feed_item(feed_item, screen_width)
      })
    end

    {:noreply, socket}
  end

  # TODO test
  # TODO optimise pubsub, and use fastlane
  def handle_info({Feeds2, :deactivated, user_id}, socket) do
    push(socket, "deactivated", %{"user_id" => user_id})
    {:noreply, socket}
  end

  defp render_feed_item(feed_item, screen_width) do
    {%FeedProfile{} = profile, %ActiveSession{} = session} = feed_item

    render(TWeb.FeedView, "feed_item.json",
      profile: profile,
      session: session,
      screen_width: screen_width
    )
  end

  defp render_feed(feed, screen_width) do
    Enum.map(feed, fn feed_item -> render_feed_item(feed_item, screen_width) end)
  end

  defp render_session(session) do
    render(TWeb.FeedView, "session.json", session: session)
  end
end
