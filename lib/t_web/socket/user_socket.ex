defmodule TWeb.UserSocket2 do
  @moduledoc false
  @behaviour TWeb.Socket
  import TWeb.Socket.ErrorHelpers
  alias T.{Accounts, Matches, Feeds, Calls, Media}

  @impl true
  def connect(%{headers: %{"authorization" => "Bearer " <> token}, peer: peer}) do
    {:ok, _assigns = %{token: token, peer: peer}}
  end

  def connect(_req) do
    {:error, _forbidden = 403}
  end

  @impl true
  def init(%{token: token, user_id: user_id, peer: {ip, port}}) do
    # find server responsible for user_id
    # send {:subscribe, user_id, self()}
    # on server, when anything comes for user_id, broadcast it to all subsribers
    # here, once a message comes,
    # Mailroom.subscribe_socket(user_id)

    :ok = Matches.subscribe_for_user(user_id)
    :ok = Accounts.subscribe_for_user(user_id)
    :ok = Feeds.subscribe_for_user(user_id)
    :ok = Feeds.subscribe_for_mode_change()

    Logger.metadata(token: token, peer: "#{:inet.ntoa(ip)}:#{port}")
    {:ok, _assigns = %{}}
  end

  @impl true
  def handle_event(event, params, assigns)

  # MEDIA

  def handle_event("upload-preflight", %{"media" => params}, assigns) do
    {:ok, Media.upload_form(params), assigns}
  end

  # /MEDIA

  # GENERAL GETTER

  # def handle_event("get", resources, %{user_id: user_id} = assigns) do
  #   newbies_live_enabled? = Application.get_env(:t, :newbies_live_enabled?)
  #   live_now? = Feeds.live_now?(user_id, utc_now(assigns), newbies_live_enabled?)
  #   {_type, [session_start, session_end]} = Feeds.live_today(utc_now(assigns))

  #   reply =
  #     Enum.map(resources, fn resource ->
  #       case resource do
  #         "known-stickers" ->
  #           Media.known_stickers()

  #         "profile" ->
  #           %Accounts.Profile{} = profile = Accounts.get_profile!(user_id)
  #           render_profile(profile)

  #         "mode" ->
  #           if live_now?, do: "live", else: "normal"

  #         "session_expiration_date" ->
  #           session_end

  #         "session_start_date" ->
  #           session_start

  #         "session_end_date" ->
  #           session_end

  #         "missed_calls" ->
  #           if live_now? do
  #             user_id
  #             |> Calls.list_live_missed_calls_with_profile(session_start)
  #             |> render_missed_calls_with_profile(screen_width)
  #           else
  #             []
  #           end

  #         "invites" ->
  #           user_id
  #           |> Feeds.list_received_invites()
  #           |> render_feed(screen_width)

  #         "matches" ->
  #           user_id
  #           |> Matches.list_live_matches()
  #           |> render_matches(screen_width)

  #         "live_session_duration" ->
  #           DateTime.diff(session_end, session_start)
  #       end
  #     end)

  #   {:ok, reply, assigns}
  # end

  # /GENERAL GETTER

  # PROFILE

  def handle_event("submit", %{"profile" => params}, %{user_id: user_id} = assigns) do
    case Accounts.submit_profile(user_id, params) do
      {:ok, profile} -> {:ok, render_profile(profile), assigns}
      {:error, %Ecto.Changeset{} = cs} -> {:error, error(:changeset, cs), assigns}
    end
  end

  def handle_event("set-audio-only", %{"bool" => bool}, %{user_id: user_id} = assigns) do
    Accounts.set_audio_only(user_id, bool)
    {:ok, assigns}
  end

  # /PROFILE

  # FEED

  def handle_event("start-feed", params, assigns) do
  end

  def handle_event("more-feed", params, assigns) do
  end

  def handle_event("seen", %{"user_id" => user_id}, assigns) do
    Feeds.mark_profile_seen(user_id, by: assigns.user_id)
    {:ok, assigns}
  end

  # /FEED

  # LIKES

  def handle_event("like", %{"user_id" => user_id}, assigns) do
    case Matches.like_user(assigns.user_id, user_id) do
      {:ok, %{match: _no_match = nil}} ->
        {:ok, assigns}

      {:ok, %{match: match, audio_only: audio_only}} ->
        {:ok, %{match_id: match.id, audio_only: audio_only}, assigns}

      {:error, _step, _reason, _changes} ->
        {:ok, assigns}
    end
  end

  def handle_event("decline", %{"user_id" => user_id}, assigns) do
    Matches.decline_like(assigns.user_id, user_id)
    {:ok, assigns}
  end

  # /LIKES

  # MATCHES

  def handle_event("archive-match", %{"match_id" => match_id}, assigns) do
    Matches.mark_match_archived(match_id, assigns.user_id)
    {:ok, assigns}
  end

  def handle_event("unarchive-match", %{"match_id" => match_id}, assigns) do
    Matches.unmatch_match(match_id, assigns.user_id)
    {:ok, assigns}
  end

  def handle_event("seen", %{"expired_match_id" => match_id}, assigns) do
    Matches.delete_expired_match(match_id, assigns.user_id)
    {:ok, assigns}
  end

  def handle_event("unmatch", %{"user_id" => user_id}, assigns) do
    {:ok, assigns}
  end

  # /MATCHES

  # TIMESLOTS

  def handle_event("offer-slots", %{"slots" => slots, "user_id" => user_id}, assigns) do
    case Matches.save_slots_offer_for_user(assigns.user_id, user_id, slots) do
      {:ok, _timeslot} ->
        {:ok, assigns}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, error(:changeset, changeset), assigns}
    end
  end

  def handle_event("pick-slot", %{"slot" => slot, "user_id" => user_id}, assigns) do
  end

  def handle_event("cancel-slot", %{"user_id" => user_id}, assigns) do
  end

  # /TIMESLOTS

  # CONTACTS
  # /CONTACTS

  # CALLS

  def handle_event("call", %{"user_id" => user_id}, assigns) do
    case Calls.call(assigns.user_id, user_id, utc_now(assigns)) do
      {:ok, call_id} ->
        {:ok, %{"call_id" => call_id, "ice-servers" => [], "call_topics" => []}, assigns}

      {:error, reason} ->
        {:error, error(reason), assigns}
    end
  end

  def handle_event("join-call", %{"user_id" => user_id}, assigns) do
    {:ok, %{"caller" => %{}, "ice-servers" => [], "call_topics" => []}, assigns}
  end

  def handle_event("pick-up", %{"call_id" => call_id}, assigns) do
  end

  def handle_event("peer-message", %{"call_id" => call_id, "body" => body}, assigns) do
  end

  def handle_event("hang-up", %{"call_id" => call_id}, assigns) do
  end

  # /CALLS

  # VOICEMAIL

  def handle_event("send-voicemail", %{"user_id" => user_id, "s3_key" => s3_key}, assigns) do
  end

  def handle_event("listen-voicemail", %{"id" => voicemail_id}, assigns) do
  end

  # /VOICEMAIL

  # REPORTS

  def handle_event("report", %{"user_id" => user_id}, assigns) do
    {:ok, assigns}
  end

  # /REPORTS

  @impl true
  def handle_info(message, assigns)

  # MATCHES

  def handle_info({Matches, :liked, like}, assigns) do
    %{by_user_id: by_user_id} = like

    if profile = Feeds.get_mate_feed_profile(by_user_id) do
      rendered = render_feed_item(profile, screen_width)
      {[push("invite", rendered)], assigns}
    else
      {_noreply = [], assigns}
    end
  end

  # /MATCHES

  @impl true
  def terminate(_reason, %{user_id: user_id}) do
    Accounts.update_last_active(user_id)
  end

  defp push(event, payload), do: [event, payload]
end
