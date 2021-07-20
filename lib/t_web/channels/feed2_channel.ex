defmodule TWeb.Feed2Channel do
  use TWeb, :channel

  alias TWeb.ChannelHelpers
  alias T.Feeds.FeedProfile
  alias T.Feeds2

  @impl true
  def join("feed2:" <> user_id, _params, socket) do
    user_id = ChannelHelpers.verify_user_id(socket, user_id)
    :ok = Feeds2.subscribe_for_invites(user_id)
    {:ok, socket}
  end

  @impl true
  def handle_in("more", params, socket) do
    %{current_user: user, screen_width: screen_width} = socket.assigns

    feed =
      Feeds2.fetch_feed(
        user.id,
        params["count"] || 10,
        ChannelHelpers.extract_timestamp(params["since"])
      )

    {:reply, {:ok, %{"feed" => render_feed(feed, screen_width)}}, socket}
  end

  def handle_in("invite", %{"user_id" => user_id}, socket) do
    invited? = Feeds2.invite_active_user(socket.assigns.current_user.id, user_id)
    {:reply, {:ok, %{"invited" => invited?}}, socket}
  end

  # def handle_in("activate-session", %{"duration" => duration}, socket) do
  # end

  def handle_in("report", %{"report" => report}, socket) do
    ChannelHelpers.report(socket, report)
  end

  @impl true
  def handle_info({Feeds2, :invited, user_id}, socket) do
    if feed_item = Feeds2.get_feed_item(user_id) do
      push(socket, "invite", %{
        "feed_item" => render_feed_item(feed_item, socket.assigns.screen_width)
      })
    end

    {:noreply, socket}
  end

  defp render_feed_item(feed_item, screen_width) do
    {%FeedProfile{} = profile, expires_at} = feed_item

    render(TWeb.FeedView, "feed_item.json",
      profile: profile,
      expires_at: expires_at,
      screen_width: screen_width
    )
  end

  defp render_feed(feed, screen_width) do
    Enum.map(feed, fn feed_item -> render_feed_item(feed_item, screen_width) end)
  end
end
