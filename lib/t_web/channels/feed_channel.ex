defmodule TWeb.FeedChannel do
  use TWeb, :channel
  import TWeb.ChannelHelpers

  alias TWeb.{FeedView, MatchView, ErrorView}
  alias T.{Feeds, Calls, Matches, Accounts}
  alias T.Feeds.FeedFilter

  @impl true
  def join("feed:" <> user_id, params, socket) do
    if ChannelHelpers.valid_user_topic?(socket, user_id) do
      user_id = String.downcase(user_id)
      %{screen_width: screen_width} = socket.assigns

      :ok = Matches.subscribe_for_user(user_id)
      :ok = Accounts.subscribe_for_user(user_id)
      :ok = Feeds.subscribe_for_user(user_id)
      :ok = Feeds.subscribe_for_mode_change()

      newbies_live_enabled? = Application.get_env(:t, :newbies_live_enabled?)

      cond do
        params["mode"] == "normal" ->
          join_normal_mode(user_id, screen_width, params, socket)

        params["mode"] == "live" ->
          join_live_mode(user_id, screen_width, socket)

        Feeds.live_now?(user_id, utc_now(socket), newbies_live_enabled?) ->
          join_live_mode(user_id, screen_width, socket)

        true ->
          join_normal_mode(user_id, screen_width, params, socket)
      end
    else
      {:error, %{"error" => "forbidden"}}
    end
  end

  defp join_live_mode(user_id, screen_width, socket) do
    %FeedFilter{genders: want_genders} = feed_filter = Feeds.get_feed_filter(user_id)
    {_location, gender} = Accounts.get_location_and_gender!(user_id)

    :ok = Feeds.subscribe_for_live_sessions(user_id, gender, want_genders)

    Feeds.maybe_activate_session(user_id, gender, feed_filter)

    {_type, [session_start, session_end]} = Feeds.live_today(utc_now(socket))
    live_session_duration = DateTime.diff(session_end, session_start)

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
      # TODO remove
      |> Map.put("session_expiration_date", session_end)
      # TODO remove
      |> Map.put("live_session_duration", live_session_duration)
      |> Map.put("session_start_date", session_start)
      |> Map.put("session_end_date", session_end)
      |> maybe_put("missed_calls", missed_calls)
      |> maybe_put("invites", invites)
      |> maybe_put("matches", matches)

    {:ok, reply, assign(socket, mode: "live", feed_filter: feed_filter, gender: gender)}
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
      |> render_matches(screen_width)

    since_live_date = Feeds.live_next_real_at(utc_now(socket))

    reply =
      %{"mode" => "normal"}
      |> Map.put("since_live_date", since_live_date)
      # TODO remove?
      |> Map.put("match_expiration_duration", Matches.pre_voicemail_ttl())
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
          %{
            feed_filter: feed_filter,
            gender: gender
          } = socket.assigns

          {feed, cursor} =
            Feeds.fetch_live_feed(
              user.id,
              gender,
              feed_filter,
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

  def handle_in("call", %{"user_id" => called}, socket) do
    caller = me_id(socket)

    reply =
      case Calls.call(caller, called, utc_now(socket)) do
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
           match: %{id: match_id, inserted_at: inserted_at},
           audio_only: [_our, mate_audio_only]
         }} ->
          # TODO return these timestamps from like_user
          inserted_at = DateTime.from_naive!(inserted_at, "Etc/UTC")
          expiration_date = DateTime.add(inserted_at, Matches.pre_voicemail_ttl())

          {:ok,
           %{
             "match_id" => match_id,
             "audio_only" => mate_audio_only,
             "expiration_date" => expiration_date,
             "inserted_at" => inserted_at,
             "exchanged_voicemail" => false
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

  def handle_in("send-contact", %{"match_id" => match_id, "contacts" => contacts}, socket) do
    me = me_id(socket)

    {:ok, %Matches.MatchContact{contacts: contacts}} =
      Matches.save_contacts_offer_for_match(me, match_id, contacts)

    {:reply, {:ok, %{"contacts" => contacts}}, socket}
  end

  def handle_in("cancel-contact", %{"match_id" => match_id}, socket) do
    me = me_id(socket)

    :ok = Matches.cancel_contacts_for_match(me, match_id)

    {:reply, :ok, socket}
  end

  def handle_in("open-contact", %{"match_id" => match_id, "contact_type" => contact_type}, socket) do
    me = me_id(socket)

    :ok = Matches.open_contact_for_match(me, match_id, contact_type, utc_now(socket))

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

  # voicemail

  def handle_in("send-voicemail", %{"match_id" => match_id, "s3_key" => s3_key}, socket) do
    reply =
      case Calls.voicemail_save_message(me_id(socket), match_id, s3_key) do
        {:ok, %Calls.Voicemail{id: message_id}, new_expiration_date} ->
          {:ok, maybe_put(%{"id" => message_id}, "expiration_date", new_expiration_date)}

        {:error, reason} ->
          {:error, %{"reason" => reason}}
      end

    {:reply, reply, socket}
  end

  def handle_in("listen-voicemail", %{"id" => voicemail_id}, socket) do
    Calls.voicemail_listen_message(me_id(socket), voicemail_id, utc_now(socket))
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

    %{
      id: match_id,
      inserted_at: inserted_at,
      expiration_date: expiration_date,
      mate: mate_id,
      audio_only: audio_only
    } = match

    if profile = Feeds.get_mate_feed_profile(mate_id) do
      push(socket, "matched", %{
        "match" =>
          render_match(%{
            id: match_id,
            audio_only: audio_only,
            profile: profile,
            screen_width: screen_width,
            inserted_at: inserted_at,
            expiration_date: expiration_date,
            exchanged_voice: false
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
      contacts: contacts,
      match_id: match_id
    } = match_contact

    push(socket, "contact_offer", %{
      "match_id" => match_id,
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

  def handle_info({Calls, [:voicemail, :received], payload}, socket) do
    %{voicemail: voicemail, expiration_date: expiration_date} = payload

    %Calls.Voicemail{
      id: id,
      s3_key: s3_key,
      match_id: match_id,
      inserted_at: inserted_at
    } = voicemail

    push = %{
      "match_id" => match_id,
      "id" => id,
      "s3_key" => s3_key,
      "url" => Calls.voicemail_url(s3_key),
      "inserted_at" => DateTime.from_naive!(inserted_at, "Etc/UTC")
    }

    push = maybe_put(push, "expiration_date", expiration_date)
    push(socket, "voicemail_received", push)

    {:noreply, socket}
  end

  def handle_info({Feeds, [:mode_change, event]}, socket) do
    socket =
      case {event, socket.assigns[:mode]} do
        {:start, "normal"} ->
          push(socket, "live_mode_started", %{})
          assign(socket, mode: "live")

        {:end, "live"} ->
          push(socket, "live_mode_ended", %{})
          assign(socket, mode: "normal")

        _other ->
          socket
      end

    {:noreply, socket}
  end

  # TODO test
  def handle_info({Feeds, :live, %{profile: feed_profile}}, socket) do
    %{screen_width: screen_width} = socket.assigns
    push(socket, "activated_profile", render_feed_item(feed_profile, screen_width))
    {:noreply, socket}
  end

  def handle_info(
        {Feeds, :live_match_online, %{profile: feed_profile, match_id: match_id}},
        socket
      ) do
    %{screen_width: screen_width} = socket.assigns
    match = render_match(%{id: match_id, profile: feed_profile, screen_width: screen_width})
    push(socket, "activated_match", %{"match" => match})
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
    Enum.map(matches, fn
      %Matches.Match{
        id: match_id,
        inserted_at: inserted_at,
        audio_only: audio_only,
        profile: profile,
        timeslot: timeslot,
        contact: contact,
        voicemail: voicemail,
        expiration_date: expiration_date,
        exchanged_voicemail: exchanged_voice
      } ->
        render_match(%{
          id: match_id,
          inserted_at: inserted_at,
          audio_only: audio_only,
          profile: profile,
          timeslot: timeslot,
          contact: contact,
          voicemail: voicemail,
          screen_width: screen_width,
          expiration_date: expiration_date,
          exchanged_voice: exchanged_voice
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
