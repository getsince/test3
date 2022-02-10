defmodule TWeb.FeedChannel do
  use TWeb, :channel
  import TWeb.ChannelHelpers

  alias TWeb.{FeedView, MatchView}
  alias T.{Feeds, Matches, Accounts}

  @impl true
  def join("feed:" <> user_id, _params, socket) do
    if ChannelHelpers.valid_user_topic?(socket, user_id) do
      user_id = String.downcase(user_id)
      %{screen_width: screen_width} = socket.assigns

      :ok = Matches.subscribe_for_user(user_id)
      :ok = Accounts.subscribe_for_user(user_id)
      :ok = Feeds.subscribe_for_user(user_id)

      join_normal_mode(user_id, screen_width, socket)
    else
      {:error, %{"error" => "forbidden"}}
    end
  end

  defp join_normal_mode(user_id, screen_width, socket) do
    feed_filter = Feeds.get_feed_filter(user_id)
    {location, gender} = Accounts.get_location_and_gender!(user_id)

    likes =
      user_id
      |> Feeds.list_received_likes()
      |> render_feed(screen_width)

    matches =
      user_id
      |> Matches.list_matches()
      |> render_matches(screen_width)

    expired_matches =
      user_id
      |> Matches.list_expired_matches()
      |> render_matches(screen_width)

    archived_matches =
      user_id
      |> Matches.list_archived_matches()
      |> render_matches(screen_width)

    reply =
      %{}
      |> maybe_put("likes", likes)
      |> maybe_put("matches", matches)
      |> maybe_put("expired_matches", expired_matches)
      |> maybe_put("archived_matches", archived_matches)

    {:ok, reply,
     assign(socket,
       feed_filter: feed_filter,
       location: location,
       gender: gender
     )}
  end

  @impl true
  def handle_in("more", params, socket) do
    %{
      current_user: user,
      screen_width: screen_width,
      feed_filter: feed_filter,
      gender: gender,
      location: location
    } = socket.assigns

    {feed, cursor} =
      Feeds.fetch_feed(
        user.id,
        location,
        gender,
        feed_filter,
        params["count"] || 10,
        params["cursor"]
      )

    {:reply, {:ok, %{"feed" => render_feed(feed, screen_width), "cursor" => cursor}}, socket}
  end

  def handle_in("archived-matches", _params, socket) do
    %{current_user: user, screen_width: screen_width} = socket.assigns

    archived_matches =
      user.id
      |> Matches.list_archived_matches()
      |> render_matches(screen_width)

    {:reply, {:ok, %{"archived_matches" => archived_matches}}, socket}
  end

  def handle_in("archive-match", %{"match_id" => match_id}, socket) do
    Matches.mark_match_archived(match_id, me_id(socket))
    {:reply, :ok, socket}
  end

  def handle_in("unarchive-match", %{"match_id" => match_id}, socket) do
    Matches.unarchive_match(match_id, me_id(socket))
    {:reply, :ok, socket}
  end

  # TODO possibly batch
  def handle_in("seen", %{"user_id" => user_id}, socket) do
    Feeds.mark_profile_seen(user_id, by: me_id(socket))
    {:reply, :ok, socket}
  end

  def handle_in("seen", %{"expired_match_id" => match_id}, socket) do
    by_user_id = me_id(socket)
    Matches.delete_expired_match(match_id, by_user_id)
    {:reply, :ok, socket}
  end

  def handle_in("like", %{"user_id" => liked}, socket) do
    %{current_user: %{id: liker}} = socket.assigns

    # TODO check that we had a call?

    reply =
      case Matches.like_user(liker, liked) do
        {:ok, %{match: _no_match = nil}} ->
          :ok

        {:ok,
         %{
           match: %{id: match_id, inserted_at: inserted_at}
         }} ->
          # TODO return these timestamps from like_user
          inserted_at = DateTime.from_naive!(inserted_at, "Etc/UTC")
          expiration_date = DateTime.add(inserted_at, Matches.match_ttl())

          {:ok,
           %{
             "match_id" => match_id,
             "expiration_date" => expiration_date,
             "inserted_at" => inserted_at
           }}

        {:error, _step, _reason, _changes} ->
          :ok
      end

    {:reply, reply, socket}
  end

  def handle_in("decline", %{"user_id" => liker}, socket) do
    %{current_user: %{id: user}} = socket.assigns

    reply =
      case Matches.decline_like(user, liker) do
        {:ok, %{}} -> :ok
        {:error, _step, _reason, _changes} -> :ok
      end

    {:reply, reply, socket}
  end

  def handle_in("unmatch", params, socket) do
    unmatched? =
      case params do
        %{"user_id" => user_id} -> Matches.unmatch_with_user(me_id(socket), user_id)
        %{"match_id" => match_id} -> Matches.unmatch_match(me_id(socket), match_id)
      end

    {:reply, {:ok, %{"unmatched?" => unmatched?}}, socket}
  end

  def handle_in("report", params, socket) do
    report(socket, params)
  end

  @impl true
  def handle_info({Matches, :liked, like}, socket) do
    %{screen_width: screen_width} = socket.assigns
    %{by_user_id: by_user_id} = like

    if profile = Feeds.get_mate_feed_profile(by_user_id) do
      rendered = render_feed_item(profile, screen_width)
      push(socket, "invite", rendered)
    end

    {:noreply, socket}
  end

  def handle_info({Matches, :matched, match}, socket) do
    %{screen_width: screen_width} = socket.assigns

    %{
      id: match_id,
      inserted_at: inserted_at,
      expiration_date: expiration_date,
      mate: mate_id
    } = match

    if profile = Feeds.get_mate_feed_profile(mate_id) do
      push(socket, "matched", %{
        "match" =>
          render_match(%{
            id: match_id,
            profile: profile,
            screen_width: screen_width,
            inserted_at: inserted_at,
            expiration_date: expiration_date
          })
      })
    end

    {:noreply, socket}
  end

  def handle_info({Matches, :unmatched, match_id}, socket) when is_binary(match_id) do
    push(socket, "unmatched", %{"match_id" => match_id})
    {:noreply, socket}
  end

  def handle_info({Matches, :expired, match_id}, socket) when is_binary(match_id) do
    push(socket, "match_expired", %{"match_id" => match_id})
    {:noreply, socket}
  end

  def handle_info({Accounts, :feed_filter_updated, feed_filter}, socket) do
    {:noreply, assign(socket, :feed_filter, feed_filter)}
  end

  defp render_feed_item(profile, screen_width) do
    assigns = [profile: profile, screen_width: screen_width]
    render(FeedView, "feed_item.json", assigns)
  end

  defp render_feed(feed, screen_width) do
    Enum.map(feed, fn feed_item -> render_feed_item(feed_item, screen_width) end)
  end

  defp render_matches(matches, screen_width) do
    Enum.map(matches, fn
      %Matches.Match{
        id: match_id,
        inserted_at: inserted_at,
        profile: profile,
        expiration_date: expiration_date
      } ->
        render_match(%{
          id: match_id,
          inserted_at: inserted_at,
          profile: profile,
          screen_width: screen_width,
          expiration_date: expiration_date
        })

      %Matches.ExpiredMatch{
        match_id: match_id,
        profile: profile
      } ->
        render_match(%{id: match_id, profile: profile, screen_width: screen_width})

      %Matches.ArchivedMatch{
        match_id: match_id,
        profile: profile
      } ->
        render_match(%{id: match_id, profile: profile, screen_width: screen_width})
    end)
  end

  @compile inline: [render_match: 1]
  defp render_match(assigns) do
    render(MatchView, "match.json", assigns)
  end
end
