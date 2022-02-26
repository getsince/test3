defmodule TWeb.FeedChannel do
  use TWeb, :channel
  import TWeb.ChannelHelpers

  alias TWeb.{FeedView, MatchView, ErrorView}
  alias T.{Feeds, Calls, Matches, Accounts, Events, News}

  @impl true
  def join("feed:" <> user_id, params, socket) do
    if ChannelHelpers.valid_user_topic?(socket, user_id) do
      if locale = socket.assigns[:locale] do
        Gettext.put_locale(locale)
      end

      user_id = String.downcase(user_id)

      :ok = Matches.subscribe_for_user(user_id)
      :ok = Accounts.subscribe_for_user(user_id)
      :ok = Feeds.subscribe_for_user(user_id)

      join_normal_mode(user_id, params, socket)
    else
      {:error, %{"error" => "forbidden"}}
    end
  end

  defp join_normal_mode(user_id, params, socket) do
    feed_filter = Feeds.get_feed_filter(user_id)
    {location, gender} = Accounts.get_location_and_gender!(user_id)

    %{screen_width: screen_width, version: version} = socket.assigns

    missed_calls =
      user_id
      |> Calls.list_missed_calls_with_profile(after: params["missed_calls_cursor"])
      |> render_missed_calls_with_profile(version, screen_width)

    likes =
      user_id
      |> Feeds.list_received_likes()
      |> render_likes(version, screen_width)

    matches =
      user_id
      |> Matches.list_matches()
      |> render_matches(version, screen_width)

    expired_matches =
      user_id
      |> Matches.list_expired_matches()
      |> render_matches(version, screen_width)

    archived_matches =
      user_id
      |> Matches.list_archived_matches()
      |> render_matches(version, screen_width)

    news =
      user_id
      |> News.list_news()
      |> render_news(version, screen_width)

    reply =
      %{}
      |> maybe_put("news", news)
      |> maybe_put("missed_calls", missed_calls)
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
      version: version,
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

    {:reply, {:ok, %{"feed" => render_feed(feed, version, screen_width), "cursor" => cursor}},
     socket}
  end

  def handle_in("archived-matches", _params, socket) do
    %{current_user: user, screen_width: screen_width, version: version} = socket.assigns

    archived_matches =
      user.id
      |> Matches.list_archived_matches()
      |> render_matches(version, screen_width)

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
  def handle_in("seen", %{"user_id" => user_id} = params, socket) do
    me = me_id(socket)

    if timings = params["timings"] do
      Events.save_seen_timings(:feed, me, user_id, timings)
    end

    Feeds.mark_profile_seen(user_id, by: me)
    {:reply, :ok, socket}
  end

  def handle_in("seen", %{"expired_match_id" => match_id}, socket) do
    by_user_id = me_id(socket)
    Matches.delete_expired_match(match_id, by_user_id)
    {:reply, :ok, socket}
  end

  def handle_in("seen", %{"news_story_id" => news_story_id}, socket) do
    News.mark_seen(me_id(socket), news_story_id)
    {:reply, :ok, socket}
  end

  def handle_in("seen-match", %{"match_id" => match_id} = params, socket) do
    me = me_id(socket)

    if timings = params["timings"] do
      Events.save_seen_timings(:match, me, match_id, timings)
    end

    Matches.mark_match_seen(me, match_id)
    {:reply, :ok, socket}
  end

  def handle_in("seen-like", %{"user_id" => by_user_id} = params, socket) do
    me = me_id(socket)

    if timings = params["timings"] do
      Events.save_seen_timings(:like, me, by_user_id, timings)
    end

    Matches.mark_like_seen(me, by_user_id)
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
    %{current_user: %{id: liker}, screen_width: screen_width, version: version} = socket.assigns

    Events.save_like(liker, liked)

    # TODO check that we had a call?

    reply =
      case Matches.like_user(liker, liked) do
        {:ok, %{match: _no_match = nil}} ->
          :ok

        {:ok,
         %{
           match: %{id: match_id, inserted_at: inserted_at},
           mutual: profile,
           audio_only: [_our, mate_audio_only]
         }} ->
          # TODO return these timestamps from like_user
          expiration_date = NaiveDateTime.add(inserted_at, Matches.match_ttl())

          rendered =
            render_match(%{
              id: match_id,
              profile: profile,
              screen_width: screen_width,
              version: version,
              audio_only: mate_audio_only,
              expiration_date: expiration_date,
              inserted_at: inserted_at
            })
            |> Map.put("match_id", match_id)
            #  TODO remove after adoption of iOS 5.1.0
            |> Map.put("exchanged_voicemail", false)

          {:ok, rendered}

        {:error, _step, _reason, _changes} ->
          :ok
      end

    {:reply, reply, socket}
  end

  def handle_in("decline", %{"user_id" => liker}, socket) do
    Matches.decline_like(me_id(socket), liker)
    {:reply, :ok, socket}
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

  def handle_in("open-contact", %{"match_id" => match_id, "contact_type" => contact_type}, socket) do
    me = me_id(socket)

    :ok = Matches.open_contact_for_match(me, match_id, contact_type, utc_now(socket))

    {:reply, :ok, socket}
  end

  def handle_in("click-contact", %{"user_id" => user_id, "contact" => contact}, socket) do
    me = me_id(socket)
    Events.save_contact_click(me, user_id, contact)

    if match_id = Matches.get_match_id([me, user_id]) do
      Matches.save_contact_click(match_id)
    end

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

  # voicemail

  def handle_in("send-voicemail", %{"match_id" => match_id, "s3_key" => s3_key}, socket) do
    reply =
      case Calls.voicemail_save_message(me_id(socket), match_id, s3_key) do
        {:ok, %Calls.Voicemail{id: message_id}} -> {:ok, %{"id" => message_id}}
        {:error, reason} -> {:error, %{"reason" => reason}}
      end

    {:reply, reply, socket}
  end

  def handle_in("listen-voicemail", %{"id" => voicemail_id}, socket) do
    Calls.voicemail_listen_message(me_id(socket), voicemail_id, utc_now(socket))
    {:reply, :ok, socket}
  end

  # history

  def handle_in("list-interactions", %{"match_id" => match_id}, socket) do
    interactions = Matches.history_list_interactions(match_id)
    {:reply, {:ok, %{"interactions" => render_interactions(interactions)}}, socket}
  end

  @impl true
  def handle_info({Matches, :liked, like}, socket) do
    %{screen_width: screen_width, version: version} = socket.assigns
    %{by_user_id: by_user_id} = like

    if profile = Feeds.get_mate_feed_profile(by_user_id) do
      rendered = render_feed_item(profile, version, screen_width)
      push(socket, "invite", rendered)
    end

    {:noreply, socket}
  end

  def handle_info({Matches, :matched, match}, socket) do
    %{screen_width: screen_width, version: version} = socket.assigns

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
            version: version,
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

  def handle_info({Matches, [:timeslot, :started], match_id}, socket) do
    push(socket, "timeslot_started", %{"match_id" => match_id})
    {:noreply, socket}
  end

  def handle_info({Matches, [:timeslot, :ended], match_id}, socket) do
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

  def handle_info({Accounts, :feed_filter_updated, feed_filter}, socket) do
    {:noreply, assign(socket, :feed_filter, feed_filter)}
  end

  def handle_info({Calls, [:voicemail, :received], voicemail}, socket) do
    %Calls.Voicemail{
      id: id,
      s3_key: s3_key,
      match_id: match_id,
      inserted_at: inserted_at
    } = voicemail

    push(socket, "voicemail_received", %{
      "match_id" => match_id,
      "id" => id,
      "s3_key" => s3_key,
      "url" => Calls.voicemail_url(s3_key),
      "inserted_at" => DateTime.from_naive!(inserted_at, "Etc/UTC")
    })

    {:noreply, socket}
  end

  def handle_info({Matches, :interaction, interaction}, socket) do
    %Matches.Interaction{match_id: match_id} = interaction

    push(socket, "interaction", %{
      "match_id" => match_id,
      "interaction" => render_interaction(interaction)
    })

    {:noreply, socket}
  end

  defp render_feed_item(profile, version, screen_width) do
    assigns = [profile: profile, screen_width: screen_width, version: version]
    render(FeedView, "feed_item.json", assigns)
  end

  defp render_feed(feed, version, screen_width) do
    Enum.map(feed, fn feed_item -> render_feed_item(feed_item, version, screen_width) end)
  end

  defp render_likes(likes, version, screen_width) do
    Enum.map(likes, fn %{profile: profile, seen: seen} ->
      profile
      |> render_feed_item(version, screen_width)
      |> maybe_put("seen", seen)
    end)
  end

  defp render_changeset(changeset) do
    render(ErrorView, "changeset.json", changeset: changeset)
  end

  defp render_missed_calls_with_profile(missed_calls, version, screen_width) do
    Enum.map(missed_calls, fn {call, profile} ->
      render(FeedView, "missed_call.json",
        profile: profile,
        call: call,
        screen_width: screen_width,
        version: version
      )
    end)
  end

  defp render_matches(matches, version, screen_width) do
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
        last_interaction_id: last_interaction_id,
        seen: seen
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
          version: version,
          expiration_date: expiration_date,
          last_interaction_id: last_interaction_id,
          seen: seen
        })

      %Matches.ExpiredMatch{
        match_id: match_id,
        profile: profile
      } ->
        render_match(%{
          id: match_id,
          profile: profile,
          version: version,
          screen_width: screen_width
        })

      %Matches.ArchivedMatch{
        match_id: match_id,
        profile: profile
      } ->
        render_match(%{
          id: match_id,
          profile: profile,
          version: version,
          screen_width: screen_width
        })
    end)
  end

  @compile inline: [render_match: 1]
  defp render_match(assigns) do
    render(MatchView, "match.json", assigns)
  end

  defp render_interactions(interactions) do
    Enum.map(interactions, &render_interaction/1)
  end

  defp render_interaction(interaction) do
    render(MatchView, "interaction.json", interaction: interaction)
  end

  defp render_news(news, version, screen_width) do
    alias TWeb.ViewHelpers

    Enum.map(news, fn %{story: story} = news ->
      %{news | story: ViewHelpers.postprocess_story(story, version, screen_width, :feed)}
    end)
  end
end
