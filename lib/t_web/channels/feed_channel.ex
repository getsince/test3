defmodule TWeb.FeedChannel do
  use TWeb, :channel
  import TWeb.ChannelHelpers

  alias TWeb.{FeedView, MatchView, ViewHelpers}
  alias T.{Feeds, Matches, Accounts, Events, News, Todos}

  @impl true
  def join("feed:" <> user_id, params, socket) do
    if ChannelHelpers.valid_user_topic?(socket, user_id) do
      if locale = socket.assigns[:locale] do
        Gettext.put_locale(locale)
      end

      if params["onboarding_mode"] do
        join_onboarding_mode(params, socket)
      else
        user_id = String.downcase(user_id)

        :ok = Matches.subscribe_for_user(user_id)
        :ok = Accounts.subscribe_for_user(user_id)
        :ok = Feeds.subscribe_for_user(user_id)

        join_normal_mode(user_id, params, socket)
      end
    else
      {:error, %{"error" => "forbidden"}}
    end
  end

  defp join_onboarding_mode(params, socket) do
    %{remote_ip: remote_ip, screen_width: screen_width, version: version} = socket.assigns

    feed =
      case params["need_feed"] do
        true ->
          Feeds.fetch_onboarding_feed(remote_ip) |> render_onboarding_feed(version, screen_width)

        _ ->
          nil
      end

    reply = %{} |> maybe_put_with_empty_list("feed", feed)

    {:ok, reply, assign(socket, mode: :onboarding)}
  end

  defp join_normal_mode(user_id, params, socket) do
    feed_filter = Feeds.get_feed_filter(user_id)
    {old_location, gender, hidden?} = Accounts.get_location_gender_hidden?(user_id)

    location = socket.assigns.location || old_location
    %{screen_width: screen_width, version: version} = socket.assigns

    likes =
      user_id
      |> Feeds.list_received_likes(location)
      |> render_likes(version, screen_width)

    matches =
      user_id
      |> Matches.list_matches(location)
      |> render_matches(version, screen_width)

    news =
      user_id
      |> News.list_news(version)
      |> render_news(version, screen_width)

    todos =
      user_id
      |> Todos.list_todos(version, hidden?)
      |> render_news(version, screen_width)

    feed =
      case params["need_feed"] do
        true -> fetch_feed(user_id, location, gender, feed_filter, version, screen_width, true)
        _ -> nil
      end

    reply =
      %{}
      |> maybe_put("news", news)
      |> maybe_put("todos", todos)
      |> maybe_put("likes", likes)
      |> maybe_put("matches", matches)
      |> maybe_put_with_empty_list("feed", feed)

    {:ok, reply,
     assign(socket, feed_filter: feed_filter, location: location, gender: gender, mode: :normal)}
  end

  @impl true
  def handle_in("more", _params, socket) do
    %{
      current_user: user,
      screen_width: screen_width,
      version: version,
      feed_filter: feed_filter,
      gender: gender,
      location: location
    } = socket.assigns

    feed = fetch_feed(user.id, location, gender, feed_filter, version, screen_width, false)

    {:reply, {:ok, %{"feed" => feed}}, socket}
  end

  # TODO possibly batch
  def handle_in("seen", %{"user_id" => user_id} = params, socket) do
    me = me_id(socket)
    %{mode: mode} = socket.assigns

    if timings = params["timings"] do
      Events.save_seen_timings(:feed, me, user_id, timings)
    end

    if mode == :normal, do: Feeds.mark_profile_seen(user_id, by: me)

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

  # TODO remove
  def handle_in("reached-limit", _params, socket) do
    {:reply, :ok, socket}
  end

  def handle_in("like", %{"user_id" => liked}, socket) do
    %{
      current_user: %{id: liker},
      screen_width: screen_width,
      version: version,
      location: location
    } = socket.assigns

    Events.save_like(liker, liked)

    reply =
      case Matches.like_user(liker, liked, location) do
        {:ok, %{match: _no_match = nil}} ->
          :ok

        {:ok,
         %{
           match: %{id: match_id, inserted_at: inserted_at},
           mutual: profile
         }} ->
          # TODO return these timestamps from like_user
          expiration_date = NaiveDateTime.add(inserted_at, Matches.match_ttl())

          rendered =
            render_match(%{
              id: match_id,
              profile: profile,
              screen_width: screen_width,
              version: version,
              expiration_date: expiration_date,
              inserted_at: inserted_at
            })
            |> Map.put("match_id", match_id)

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

  # interactions

  def handle_in(
        "send-interaction",
        %{"match_id" => match_id, "interaction" => interaction},
        socket
      ) do
    %{current_user: %{id: from_user_id}} = socket.assigns

    case Matches.save_interaction(match_id, from_user_id, interaction) do
      {:ok, interaction} ->
        {:reply, {:ok, %{"interaction" => render_interaction(interaction)}}, socket}

      {:error, _changeset} ->
        {:reply, :error, socket}
    end
  end

  def handle_in("seen-interaction", %{"interaction_id" => interaction_id}, socket) do
    %{current_user: %{id: by_user_id}} = socket.assigns

    reply = Matches.mark_interaction_seen(by_user_id, interaction_id)
    {:reply, reply, socket}
  end

  # onboarding events

  def handle_in(
        "onboarding-event",
        %{"timestamp" => timestamp, "stage" => stage, "event" => event},
        socket
      ) do
    %{current_user: %{id: user_id}} = socket.assigns

    reply = Accounts.save_onboarding_event(user_id, timestamp, stage, event)
    {:reply, reply, socket}
  end

  @impl true
  def handle_info({Matches, :liked, like}, socket) do
    %{screen_width: screen_width, version: version, location: location} = socket.assigns
    %{by_user_id: by_user_id} = like

    if profile = Feeds.get_mate_feed_profile(by_user_id, location) do
      rendered = render_feed_item(profile, version, screen_width)
      push(socket, "invite", rendered)
    end

    {:noreply, socket}
  end

  def handle_info({Matches, :matched, match}, socket) do
    %{screen_width: screen_width, version: version, location: location} = socket.assigns

    %{
      id: match_id,
      inserted_at: inserted_at,
      expiration_date: expiration_date,
      mate: mate_id
    } = match

    if profile = Feeds.get_mate_feed_profile(mate_id, location) do
      push(socket, "matched", %{
        "match" =>
          render_match(%{
            id: match_id,
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

  def handle_info({Matches, :interaction, interaction}, socket) do
    %Matches.Interaction{match_id: match_id} = interaction

    push(socket, "interaction", %{
      "match_id" => match_id,
      "interaction" => render_interaction(interaction)
    })

    {:noreply, socket}
  end

  def handle_info({Accounts, :feed_filter_updated, feed_filter}, socket) do
    %{current_user: user, feed_filter: old_feed_filter} = socket.assigns

    if feed_filter != old_feed_filter do
      Feeds.empty_feeded_profiles(user.id)
      {:noreply, assign(socket, :feed_filter, feed_filter)}
    else
      {:noreply, socket}
    end
  end

  defp fetch_feed(user_id, location, gender, feed_filter, version, screen_width, first_fetch) do
    feed_reply = Feeds.fetch_feed(user_id, location, gender, feed_filter, first_fetch)
    render_fetch_feed(feed_reply, version, screen_width)
  end

  defp render_fetch_feed(feed_reply, version, screen_width) do
    case feed_reply do
      feed when is_list(feed) ->
        render_feed(feed_reply, version, screen_width)

      {%DateTime{} = timestamp, feed_limit_story} ->
        %{
          "feed_limit_expiration" => timestamp,
          "story" => render_story(feed_limit_story, version, screen_width)
        }
    end
  end

  defp render_feed_item(profile, version, screen_width) do
    assigns = [profile: profile, screen_width: screen_width, version: version]
    render(FeedView, "feed_item.json", assigns)
  end

  defp render_feed(feed, version, screen_width) do
    Enum.map(feed, fn feed_item -> render_feed_item(feed_item, version, screen_width) end)
  end

  defp render_onboarding_feed(feed, version, screen_width) do
    Enum.map(feed, fn %{profile: feed_item, categories: categories} ->
      render_feed_item(feed_item, version, screen_width) |> Map.put_new("categories", categories)
    end)
  end

  defp render_likes(likes, version, screen_width) do
    Enum.map(likes, fn %{profile: profile, seen: seen} ->
      profile
      |> render_feed_item(version, screen_width)
      |> maybe_put("seen", seen)
    end)
  end

  defp render_matches(matches, version, screen_width) do
    Enum.map(matches, fn match ->
      %Matches.Match{
        id: match_id,
        inserted_at: inserted_at,
        profile: profile,
        expiration_date: expiration_date,
        seen: seen,
        interactions: interactions
      } = match

      render_match(%{
        id: match_id,
        inserted_at: inserted_at,
        profile: profile,
        screen_width: screen_width,
        version: version,
        expiration_date: expiration_date,
        seen: seen,
        interactions: interactions
      })
    end)
  end

  defp render_match(assigns) do
    render(MatchView, "match.json", assigns)
  end

  defp render_interaction(interaction) do
    render(MatchView, "interaction.json", interaction: interaction)
  end

  defp render_news(news, version, screen_width) do
    Enum.map(news, fn %{story: story} = news ->
      %{news | story: ViewHelpers.postprocess_story(story, version, screen_width, :feed)}
    end)
  end

  defp render_story(story, version, screen_width) do
    ViewHelpers.postprocess_story(story, version, screen_width, :feed)
  end
end
