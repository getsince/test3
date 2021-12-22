defmodule TWeb.FeedChannel do
  use TWeb, :channel
  import TWeb.ChannelHelpers

  alias TWeb.{FeedView, MatchView, ErrorView}
  alias T.{Feeds, Calls, Matches, Accounts}

  @match_ttl 604_800
  @live_session_duration 7200

  @impl true
  def join("feed:" <> user_id, params, socket) do
    if ChannelHelpers.valid_user_topic?(socket, user_id) do
      user_id = String.downcase(user_id)
      %{screen_width: screen_width} = socket.assigns

      :ok = Matches.subscribe_for_user(user_id)
      :ok = Accounts.subscribe_for_user(user_id)
      :ok = Feeds.subscribe_for_mode_change()

      cond do
        params["mode"] == "normal" -> join_normal_mode(user_id, screen_width, params, socket)
        params["mode"] == "live" -> join_live_mode(user_id, screen_width, socket)
        Feeds.is_now_live_mode() -> join_live_mode(user_id, screen_width, socket)
        true -> join_normal_mode(user_id, screen_width, params, socket)
      end
    else
      {:error, %{"error" => "forbidden"}}
    end
  end

  defp join_live_mode(user_id, screen_width, socket) do
    :ok = Feeds.subscribe_for_live_sessions()
    :ok = Feeds.subscribe_for_user(user_id)

    Feeds.maybe_activate_session(user_id)

    {session_start, session_end} = Feeds.live_mode_start_and_end_dates()

    missed_calls =
      user_id
      |> Calls.list_live_missed_calls_with_profile(session_start)
      |> render_missed_calls_with_profile(screen_width)

    invites =
      user_id
      |> Feeds.list_received_invites()
      |> render_feed(screen_width)

    matches =
      user_id
      |> Matches.list_live_matches()
      |> render_matches(screen_width)

    reply =
      %{"mode" => "live"}
      |> Map.put("session_expiration_date", session_end)
      |> Map.put("live_session_duration", @live_session_duration)
      |> maybe_put("missed_calls", missed_calls)
      |> maybe_put("invites", invites)
      |> maybe_put("matches", matches)

    {:ok, reply, assign(socket, mode: "live")}
  end

  defp join_normal_mode(user_id, screen_width, params, socket) do
    feed_filter = Feeds.get_feed_filter(user_id)
    {location, gender} = Accounts.get_location_and_gender!(user_id)

    missed_calls =
      user_id
      |> Calls.list_missed_calls_with_profile(after: params["missed_calls_cursor"])
      |> render_missed_calls_with_profile(screen_width)

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
      |> render_expired_matches(screen_width)

    reply =
      %{"mode" => "normal"}
      |> Map.put("since_live_time_text", Feeds.since_live_time_text())
      |> Map.put("since_live_date", Feeds.since_live_date())
      |> Map.put("match_expiration_duration", @match_ttl)
      |> maybe_put("missed_calls", missed_calls)
      |> maybe_put("likes", likes)
      |> maybe_put("matches", matches)
      |> maybe_put("expired_matches", expired_matches)

    {:ok, reply,
     assign(socket,
       mode: "normal",
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
      mode: mode
    } = socket.assigns

    case mode do
      "live" ->
        if params["cursor"] == "non-nil" do
          {:reply, {:ok, %{"feed" => [], "cursor" => nil}}, socket}
        else
          {feed, cursor} =
            Feeds.fetch_live_feed(
              user.id,
              params["count"] || 10,
              params["cursor"]
            )

          {:reply, {:ok, %{"feed" => render_feed(feed, screen_width), "cursor" => cursor}},
           socket}
        end

      "normal" ->
        %{
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
  end

  def handle_in("archived-matches", _params, socket) do
    %{current_user: user, screen_width: screen_width} = socket.assigns

    archived_matches =
      user.id
      |> Matches.list_archived_matches()
      |> render_archived_matches(screen_width)

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
        {:ok, %{match: _no_match = nil}} ->
          :ok

        {:ok,
         %{
           match: %{id: match_id},
           audio_only: [_our, mate_audio_only],
           event: %{timestamp: timestamp}
         }} ->
          expiration_date = timestamp |> DateTime.add(@match_ttl)

          {:ok,
           %{
             "match_id" => match_id,
             "audio_only" => mate_audio_only,
             "expiration_date" => expiration_date
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
    me = me_id(socket)

    case params do
      %{"match_id" => match_id} -> Matches.cancel_slot_for_match(me, match_id)
      %{"user_id" => user_id} -> Matches.cancel_slot_for_matched_user(me, user_id)
    end

    {:reply, :ok, socket}
  end

  # TODO remove upon release of new app version
  def handle_in("send-contact", %{"match_id" => match_id, "contact" => contact}, socket) do
    me = me_id(socket)

    {:ok, _match_contact} = Matches.save_contact_offer_for_match(me, match_id, contact)

    {:reply, :ok, socket}
  end

  def handle_in("send-contact", %{"match_id" => match_id, "contacts" => contacts}, socket) do
    me = me_id(socket)

    {:ok, %Matches.MatchContact{contacts: contacts}} =
      Matches.save_contact_offer_for_match(me, match_id, contacts)

    {:reply, {:ok, %{"contacts" => contacts}}, socket}
  end

  def handle_in("cancel-contact", %{"match_id" => match_id}, socket) do
    me = me_id(socket)

    :ok = Matches.cancel_contact_for_match(me, match_id)

    {:reply, :ok, socket}
  end

  def handle_in("open-contact", %{"match_id" => match_id, "contact_type" => contact_type}, socket) do
    me = me_id(socket)

    :ok = Matches.open_contact_for_match(me, match_id, contact_type)

    {:reply, :ok, socket}
  end

  def handle_in("report-we-met", %{"match_id" => match_id}, socket) do
    me = me_id(socket)

    :ok = Matches.report_meeting(me, match_id)

    {:reply, :ok, socket}
  end

  def handle_in("report-we-not-met", %{"match_id" => match_id}, socket) do
    me = me_id(socket)

    :ok = Matches.mark_contact_not_opened(me, match_id)

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

  def handle_in("report", params, socket) do
    report(socket, params)
  end

  # Live Feed

  def handle_in("live-invite", %{"user_id" => invited}, socket) do
    %{current_user: %{id: inviter}} = socket.assigns

    Feeds.live_invite_user(inviter, invited)

    {:reply, :ok, socket}
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
    %{id: match_id, mate: mate_id, audio_only: audio_only} = match

    if profile = Feeds.get_mate_feed_profile(mate_id) do
      rendered =
        render_match(match_id, audio_only, profile, _timeslot = nil, _contact = nil, screen_width)

      push(socket, "matched", %{"match" => rendered})
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

  def handle_info({Matches, :expiration_reset, match_id}, socket) when is_binary(match_id) do
    push(socket, "match_expiration_reset", %{"match_id" => match_id})
    {:noreply, socket}
  end

  def handle_info({Matches, [:timeslot, :offered], timeslot}, socket) do
    %Matches.Timeslot{slots: slots, match_id: match_id} = timeslot

    push(socket, "slots_offer", %{
      "match_id" => match_id,
      "slots" => slots
    })

    {:noreply, socket}
  end

  def handle_info({Matches, [:timeslot, :accepted], timeslot}, socket) do
    %Matches.Timeslot{selected_slot: slot, match_id: match_id} = timeslot

    push(socket, "slot_accepted", %{
      "match_id" => match_id,
      "selected_slot" => slot
    })

    {:noreply, socket}
  end

  def handle_info({Matches, [:timeslot, :cancelled], timeslot}, socket) do
    %Matches.Timeslot{match_id: match_id} = timeslot

    push(socket, "slot_cancelled", %{"match_id" => match_id})

    {:noreply, socket}
  end

  def handle_info({Matches, [:timeslot, :start], match_id}, socket) do
    push(socket, "timeslot_started", %{"match_id" => match_id})
    {:noreply, socket}
  end

  def handle_info({Matches, [:timeslot, :end], match_id}, socket) do
    push(socket, "timeslot_ended", %{"match_id" => match_id})
    {:noreply, socket}
  end

  def handle_info({Matches, [:contact, :offered], match_contact}, socket) do
    %Matches.MatchContact{
      contact_type: contact_type,
      value: value,
      contacts: contacts,
      match_id: match_id,
      picker_id: picker_id
    } = match_contact

    push(socket, "contact_offer", %{
      "match_id" => match_id,
      # TODO remove on app release
      "contact" => %{"contact_type" => contact_type, "value" => value, "picker" => picker_id},
      "contacts" => contacts
    })

    {:noreply, socket}
  end

  def handle_info({Matches, [:contact, :cancelled], match_contact}, socket) do
    %Matches.MatchContact{match_id: match_id} = match_contact

    push(socket, "contact_cancelled", %{
      "match_id" => match_id
    })

    {:noreply, socket}
  end

  def handle_info({Accounts, :feed_filter_updated, feed_filter}, socket) do
    {:noreply, assign(socket, :feed_filter, feed_filter)}
  end

  def handle_info({Feeds, [:mode_change, event]}, socket) do
    case event do
      :start -> push(socket, "live_mode_started", %{})
      :end -> push(socket, "live_mode_ended", %{})
    end

    {:noreply, socket}
  end

  # TODO test
  # TODO reduce # queries
  # TODO optimise pubsub, and use fastlane (one encode per screen width) or move screen width logic to the client
  def handle_info({Feeds, :live, user_id}, socket) do
    %{current_user: user, screen_width: screen_width} = socket.assigns

    if feed_profile = Feeds.get_live_feed_profile(user.id, user_id) do
      if match_id = Matches.is_match?(user.id, user_id) do
        rendered =
          render_match(
            match_id,
            _audio_only = nil,
            feed_profile,
            _timeslot = nil,
            _contact = nil,
            screen_width
          )

        push(socket, "activated_match", %{"match" => rendered})
      else
        push(socket, "activated_profile", render_feed_item(feed_profile, screen_width))
      end
    end

    {:noreply, socket}
  end

  def handle_info({Feeds, :live_invited, invite}, socket) do
    %{screen_width: screen_width} = socket.assigns
    %{by_user_id: by_user_id} = invite

    if profile = Feeds.get_mate_feed_profile(by_user_id) do
      rendered = render_feed_item(profile, screen_width)
      push(socket, "live_invite", rendered)
    end

    {:noreply, socket}
  end

  defp render_feed_item(profile, screen_width) do
    assigns = [profile: profile, screen_width: screen_width]
    render(FeedView, "feed_item.json", assigns)
  end

  defp render_feed(feed, screen_width) do
    Enum.map(feed, fn feed_item -> render_feed_item(feed_item, screen_width) end)
  end

  defp render_changeset(changeset) do
    render(ErrorView, "changeset.json", changeset: changeset)
  end

  defp render_missed_calls_with_profile(missed_calls, screen_width) do
    Enum.map(missed_calls, fn {call, profile} ->
      render(FeedView, "missed_call.json",
        profile: profile,
        call: call,
        screen_width: screen_width
      )
    end)
  end

  defp render_matches(matches, screen_width) do
    Enum.map(matches, fn match ->
      %Matches.Match{
        id: match_id,
        audio_only: audio_only,
        profile: profile,
        timeslot: timeslot,
        contact: contact
      } = match

      render_match(match_id, audio_only, profile, timeslot, contact, screen_width)
    end)
  end

  defp render_expired_matches(expired_matches, screen_width) do
    Enum.map(expired_matches, fn expired_match ->
      %Matches.ExpiredMatch{
        match_id: match_id,
        profile: profile
      } = expired_match

      render_match(match_id, nil, profile, nil, nil, screen_width)
    end)
  end

  defp render_archived_matches(archived_matches, screen_width) do
    Enum.map(archived_matches, fn archived_match ->
      %Matches.ArchivedMatch{
        match_id: match_id,
        profile: profile
      } = archived_match

      render_match(match_id, nil, profile, nil, nil, screen_width)
    end)
  end

  defp render_match(
         match_id,
         maybe_audio_only,
         mate_feed_profile,
         maybe_timeslot,
         maybe_contact,
         screen_width
       ) do
    render(MatchView, "match.json",
      id: match_id,
      audio_only: maybe_audio_only,
      timeslot: maybe_timeslot,
      contact: maybe_contact,
      profile: mate_feed_profile,
      screen_width: screen_width
    )
  end
end
