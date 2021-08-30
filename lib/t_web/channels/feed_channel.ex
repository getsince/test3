defmodule TWeb.FeedChannel do
  use TWeb, :channel
  import TWeb.ChannelHelpers

  alias TWeb.{FeedView, MatchView, ErrorView}
  alias T.Feeds.{FeedProfile, ActiveSession}
  alias T.{Feeds, Calls, Matches, Accounts}

  @impl true
  def join("feed:" <> user_id, params, socket) do
    user_id = ChannelHelpers.verify_user_id(socket, user_id)
    %{screen_width: screen_width} = socket.assigns

    gender_preferences = Accounts.list_gender_preferences(user_id)

    :ok = Feeds.subscribe_for_invites(user_id)
    :ok = Feeds.subscribe_for_activated_sessions()
    :ok = Feeds.subscribe_for_deactivated_sessions()
    :ok = Matches.subscribe_for_user(user_id)

    current_session =
      if session = Feeds.get_current_session(user_id) do
        render_session(session)
      end

    missed_calls =
      user_id
      |> Calls.list_missed_calls_with_profile_and_session(after: params["missed_calls_cursor"])
      |> render_missed_calls_with_profile(screen_width)

    invites =
      user_id
      |> Feeds.list_received_invites()
      |> render_feed(screen_width)

    matches =
      user_id
      |> Matches.list_matches()
      |> render_matches(screen_width)

    reply =
      %{}
      |> maybe_put("current_session", current_session)
      |> maybe_put("missed_calls", missed_calls)
      |> maybe_put("invites", invites)
      |> maybe_put("matches", matches)

    {:ok, reply, assign(socket, gender_preferences: gender_preferences)}
  end

  @impl true
  def handle_in("more", params, socket) do
    %{current_user: user, screen_width: screen_width, gender_preferences: gender_preferences} =
      socket.assigns

    {feed, cursor} =
      Feeds.fetch_feed(user.id, gender_preferences, params["count"] || 10, params["cursor"])

    {:reply, {:ok, %{"feed" => render_feed(feed, screen_width), "cursor" => cursor}}, socket}
  end

  def handle_in("invite", %{"user_id" => user_id}, socket) do
    invited? = Feeds.invite_active_user(socket.assigns.current_user.id, user_id)
    {:reply, {:ok, %{"invited" => invited?}}, socket}
  end

  def handle_in("invites", _params, socket) do
    %{current_user: %{id: user_id}, screen_width: screen_width} = socket.assigns
    invites = user_id |> Feeds.list_received_invites() |> render_feed(screen_width)
    {:reply, {:ok, %{"invites" => invites}}, socket}
  end

  def handle_in("call", %{"user_id" => called}, socket) do
    caller = me_id(socket)

    reply =
      case Calls.call(caller, called) do
        {:ok, call_id} -> {:ok, %{"call_id" => call_id}}
        {:error, reason} -> {:error, %{"reason" => reason}}
      end

    {:reply, reply, socket}
  end

  def handle_in("like", %{"user_id" => liked}, socket) do
    %{current_user: %{id: liker}} = socket.assigns

    # TODO check that we had a call?

    reply =
      case Matches.like_user(liker, liked) do
        {:ok, %{match: _no_match = nil}} -> :ok
        {:ok, %{match: %Matches.Match{id: match_id}}} -> {:ok, %{"match_id" => match_id}}
        {:error, _step, _reason, _changes} -> :ok
      end

    {:reply, reply, socket}
  end

  def handle_in("offer-slots", %{"slots" => slots} = params, socket) do
    me = me_id(socket)

    reply =
      params
      |> case do
        %{"match_id" => match_id} -> Matches.save_slots_offer_for_match(me, match_id, slots)
        %{"user_id" => user_id} -> Matches.save_slots_offer_for_user(me, user_id, slots)
      end
      |> case do
        {:ok, _timeslot} -> :ok
        {:error, %Ecto.Changeset{} = changeset} -> {:error, render_changeset(changeset)}
      end

    {:reply, reply, socket}
  end

  def handle_in("pick-slot", %{"slot" => slot} = params, socket) do
    me = me_id(socket)

    case params do
      %{"match_id" => match_id} -> Matches.accept_slot_for_match(me, match_id, slot)
      %{"user_id" => user_id} -> Matches.accept_slot_for_matched_user(me, user_id, slot)
    end

    {:reply, :ok, socket}
  end

  def handle_in("cancel-slot", params, socket) do
    case params do
      %{"match_id" => match_id} -> Matches.cancel_slot_for_match(me_id(socket), match_id)
      %{"user_id" => user_id} -> Matches.cancel_slot_for_matched_user(me_id(socket), user_id)
    end

    {:reply, :ok, socket}
  end

  def handle_in("unmatch", params, socket) do
    unmatched? =
      case params do
        %{"user_id" => user_id} -> Matches.unmatch_with_user(me_id(socket), user_id)
        %{"match_id" => match_id} -> Matches.unmatch_match(me_id(socket), match_id)
      end

    {:reply, {:ok, %{"unmatched?" => unmatched?}}, socket}
  end

  def handle_in("activate-session", %{"duration" => duration}, socket) do
    Feeds.activate_session(me_id(socket), duration)
    {:reply, :ok, socket}
  end

  def handle_in("deactivate-session", _params, socket) do
    deactivated? = Feeds.deactivate_session(me_id(socket))
    {:reply, {:ok, %{"deactivated" => deactivated?}}, socket}
  end

  def handle_in("report", params, socket) do
    report(socket, params)
  end

  @impl true
  def handle_info({Feeds, :invited, by_user_id}, socket) do
    %{current_user: user, screen_width: screen_width} = socket.assigns

    if feed_item = Feeds.get_feed_item(user.id, by_user_id) do
      push(socket, "invite", render_feed_item(feed_item, screen_width))
    end

    {:noreply, socket}
  end

  # TODO test
  # TODO reduce # queries
  # TODO optimise pubsub, and use fastlane (one encode per screen width) or move screen width logic to the client
  def handle_info({Feeds, :activated, user_id}, socket) do
    %{current_user: user, screen_width: screen_width} = socket.assigns

    if feed_item = Feeds.get_feed_item(user.id, user_id) do
      push(socket, "activated", render_feed_item(feed_item, screen_width))
    end

    {:noreply, socket}
  end

  # TODO test
  # TODO optimise pubsub, and use fastlane
  def handle_info({Feeds, :deactivated, user_id}, socket) do
    push(socket, "deactivated", %{"user_id" => user_id})
    {:noreply, socket}
  end

  def handle_info({Matches, :matched, match}, socket) do
    %{screen_width: screen_width} = socket.assigns
    %{id: match_id, mate: mate_id} = match

    if profile = Feeds.get_mate_feed_profile(mate_id) do
      rendered = render_match(match_id, profile, _timeslot = nil, screen_width)
      push(socket, "matched", %{"match" => rendered})
    end

    {:noreply, socket}
  end

  def handle_info({Matches, :unmatched, match_id}, socket) when is_binary(match_id) do
    push(socket, "unmatched", %{"match_id" => match_id})
    {:noreply, socket}
  end

  def handle_info({Matches, [:timeslot, :offered], timeslot}, socket) do
    %Matches.Timeslot{slots: slots, match_id: match_id} = timeslot
    push(socket, "slots_offer", %{"match_id" => match_id, "slots" => slots})
    {:noreply, socket}
  end

  def handle_info({Matches, [:timeslot, :accepted], timeslot}, socket) do
    %Matches.Timeslot{selected_slot: slot, match_id: match_id} = timeslot
    push(socket, "slot_accepted", %{"match_id" => match_id, "selected_slot" => slot})
    {:noreply, socket}
  end

  def handle_info({Matches, [:timeslot, :cancelled], timeslot}, socket) do
    %Matches.Timeslot{match_id: match_id} = timeslot
    push(socket, "slot_cancelled", %{"match_id" => match_id})
    {:noreply, socket}
  end

  def handle_info({Matches, [:timeslot, :started], match_id}, socket) do
    push(socket, "timeslot_started", %{"match_id" => match_id})
    {:noreply, socket}
  end

  def handle_info({Matches, [:timeslot, :ended], match_id}, socket) do
    push(socket, "timeslot_ended", %{"match_id" => match_id})
    {:noreply, socket}
  end

  defp render_feed_item(feed_item, screen_width) do
    {%FeedProfile{} = profile, %ActiveSession{} = session} = feed_item

    render(FeedView, "feed_item.json",
      profile: profile,
      session: session,
      screen_width: screen_width
    )
  end

  defp render_feed(feed, screen_width) do
    Enum.map(feed, fn feed_item -> render_feed_item(feed_item, screen_width) end)
  end

  defp render_session(session) do
    render(FeedView, "session.json", session: session)
  end

  defp render_changeset(changeset) do
    render(ErrorView, "changeset.json", changeset: changeset)
  end

  defp render_missed_calls_with_profile(missed_calls, screen_width) do
    Enum.map(missed_calls, fn {call, profile, session} ->
      render(FeedView, "missed_call.json",
        profile: profile,
        session: session,
        call: call,
        screen_width: screen_width
      )
    end)
  end

  defp render_matches(matches, screen_width) do
    Enum.map(matches, fn match ->
      %Matches.Match{id: match_id, profile: profile, timeslot: timeslot} = match
      render_match(match_id, profile, timeslot, screen_width)
    end)
  end

  defp render_match(match_id, mate_feed_profile, maybe_timeslot, screen_width) do
    render(MatchView, "match.json",
      id: match_id,
      timeslot: maybe_timeslot,
      profile: mate_feed_profile,
      screen_width: screen_width
    )
  end
end
