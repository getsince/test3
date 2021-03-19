defmodule TWeb.MatchChannel do
  use TWeb, :channel
  alias TWeb.{ProfileView, Presence}
  alias T.{Accounts, Matches}

  @pubsub T.PubSub

  @impl true
  def join("matches:" <> user_id = topic, _params, socket) do
    user_id = String.downcase(user_id)
    ChannelHelpers.verify_user_id(socket, user_id)
    Matches.subscribe_for_user(user_id)

    matches = Matches.get_current_matches(user_id)
    Enum.each(matches, &Matches.subscribe_for_match(&1.id))

    mates = Enum.map(matches, & &1.profile.user_id)
    send(self(), {:after_join, mates})

    {:ok, %{matches: render_matches(topic, matches)}, assign(socket, mates: mates)}
  end

  @impl true
  def handle_in("peer-message" = event, %{"mate" => mate, "body" => _} = payload, socket) do
    # TODO repsond with error?
    if mate in presences(socket) do
      trace(socket, %{"event" => event, "payload" => payload})
      TWeb.Endpoint.broadcast!(mate_topic(mate), event, Map.put(payload, "mate", me(socket)))
    end

    {:reply, :ok, socket}
  end

  def handle_in(event, %{"mate" => mate}, socket)
      when event in ["call", "pick-up", "hang-up"] do
    msg = {decode_call_event(event), me(socket)}
    trace(socket, msg)
    Phoenix.PubSub.broadcast!(@pubsub, mate_topic(mate), msg)
    {:reply, :ok, socket}
  end

  def handle_in("yo", %{"match_id" => match}, socket) do
    Matches.send_yo(match: match, from: me(socket))
    {:reply, :ok, socket}
  end

  def handle_in("ice-servers", _params, socket) do
    {:reply, {:ok, %{ice_servers: T.Twilio.ice_servers()}}, socket}
  end

  def handle_in("report", %{"report" => report}, socket) do
    # TODO ensure one of mates?
    ChannelHelpers.report(socket, report)
  end

  def handle_in("unmatch", %{"match_id" => match_id}, socket) do
    me = socket.assigns.current_user.id
    Matches.unmatch_and_unhide(user: me, match: match_id)
    {:reply, :ok, socket}
  end

  @impl true
  def handle_info({Matches, [:unmatched, match_id], [_, _] = user_ids}, socket) do
    Matches.unsubscribe_from_match(match_id)
    untrack_self_for_unmatched(socket, user_ids)
    push(socket, "unmatched", %{id: match_id})
    {:noreply, socket}
  end

  def handle_info({Matches, [:matched, match_id], [_, _] = user_ids}, socket) do
    Matches.subscribe_for_match(match_id)

    me = me(socket)
    mate_id = mate_id(me, user_ids)
    mate = Accounts.get_profile!(mate_id)
    track_self_for_mate(socket, mate_id)

    rendered = render_match(match_id, mate, mate_online?(socket, mate_id))
    push(socket, "matched", %{match: rendered})

    {:noreply, socket}
  end

  def handle_info({call_event, mate}, socket) when call_event in [:call, :pick_up, :hang_up] do
    push(socket, encode_call_event(call_event), %{mate: mate})
    {:noreply, socket}
  end

  [{:call, "call"}, {:pick_up, "pick-up"}, {:hang_up, "hang-up"}]
  |> Enum.each(fn {a, s} ->
    defp encode_call_event(unquote(a)), do: unquote(s)
    defp decode_call_event(unquote(s)), do: unquote(a)
  end)

  def handle_info({:after_join, mate_ids}, socket) do
    track_self_for_mates(socket, mate_ids)
    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  ### HELPERS ###

  defp track_self_for_mates(socket, mate_ids) when is_list(mate_ids) do
    me = me(socket)

    for mate_id <- mate_ids do
      {:ok, _} = Presence.track(self(), mate_topic(mate_id), me, %{})
    end
  end

  defp track_self_for_mate(socket, mate_id) do
    me = me(socket)
    {:ok, _} = Presence.track(self(), mate_topic(mate_id), me, %{})
  end

  defp untrack_self_for_unmatched(socket, user_ids) do
    me = me(socket)
    :ok = Presence.untrack(self(), mate_topic(mate_id(me, user_ids)), me)
  end

  defp mate_topic(mate_id) do
    "matches:#{mate_id}"
  end

  defp mate_id(me, [_, _] = user_ids) do
    [mate_id] = user_ids -- [me]
    mate_id
  end

  defp me(socket) do
    socket.assigns.current_user.id
  end

  defp presences(socket) do
    socket |> Presence.list() |> Map.keys()
  end

  defp mate_online?(socket, mate_id) do
    mate_id in presences(socket)
  end

  defp render_match(match_id, profile, online?) do
    %{
      id: match_id,
      online: online?,
      profile: render_profile(profile),
      last_active: profile.last_active
    }
  end

  defp render_matches(topic, matches) do
    online = topic |> Presence.list() |> Map.keys()
    Enum.map(matches, &render_match(&1.id, &1.profile, &1.profile.user_id in online))
  end

  defp render_profile(profile) do
    render(ProfileView, "show.json", profile: profile)
  end

  defp trace(socket, message) do
    user_id = socket.assigns.current_user.id
    Phoenix.PubSub.broadcast!(@pubsub, "trace:#{user_id}", {:trace, message})
  end
end
