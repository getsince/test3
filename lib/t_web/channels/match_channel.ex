defmodule TWeb.MatchChannel do
  use TWeb, :channel
  alias TWeb.{ProfileView, Presence}
  alias T.{Accounts, Matches}

  @impl true
  def join("matches:" <> user_id = topic, _params, socket) do
    user_id = String.downcase(user_id)
    ChannelHelpers.verify_user_id(socket, user_id)
    Matches.subscribe_for_user(user_id)

    matches = Matches.get_current_matches(user_id)
    Enum.each(matches, &Matches.subscribe_for_match(&1.id))

    mates = Enum.map(matches, & &1.profile.user_id)
    send(self(), {:after_join, mates})

    {:ok, %{matches: render_matches(topic, matches)}, socket}
  end

  @impl true
  def handle_in("signal", payload, socket) do
    broadcast_from!(socket, "signal", payload)
    {:reply, :ok, socket}
  end

  def handle_in("ice-servers", _params, socket) do
    {:reply, {:ok, T.Twilio.ice_servers()}, socket}
  end

  def handle_in("report", %{"report" => report}, socket) do
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

  defp mate_online?(socket, mate_id) do
    online = socket |> Presence.list() |> Map.keys()
    mate_id in online
  end

  defp render_match(match_id, profile, online?) do
    %{id: match_id, online: online?, profile: render_profile(profile)}
  end

  defp render_matches(topic, matches) do
    online = topic |> Presence.list() |> Map.keys()
    Enum.map(matches, &render_match(&1.id, &1.profile, &1.profile.user_id in online))
  end

  defp render_profile(profile) do
    render(ProfileView, "show.json", profile: profile)
  end
end
