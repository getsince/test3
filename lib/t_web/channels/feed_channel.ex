defmodule TWeb.FeedChannel do
  use TWeb, :channel
  import TWeb.ChannelHelpers

  alias TWeb.{FeedView, ChatView, MatchView, ViewHelpers}
  alias T.{Feeds, Chats, Matches, Accounts, Events, News, Todos}
  alias T.Chats.{Chat, Message}

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

        :ok = Chats.subscribe_for_user(user_id)
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

    # TODO remove
    likes =
      user_id
      |> Feeds.list_received_likes(location)
      |> render_likes(version, screen_width)

    # TODO remove
    matches =
      user_id
      |> Matches.list_matches(location)
      |> render_matches(version, screen_width)

    chats =
      user_id
      |> Chats.list_chats(location)
      |> render_chats(version, screen_width)

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
        true ->
          category = params["category"] || "recommended"

          fetch_feed(
            user_id,
            location,
            gender,
            feed_filter,
            version,
            screen_width,
            true,
            category
          )

        _ ->
          nil
      end

    feed_categories =
      case params["need_feed"] do
        true -> Feeds.feed_categories()
        _ -> nil
      end

    reply =
      %{}
      |> maybe_put("news", news)
      |> maybe_put("todos", todos)
      |> maybe_put("chats", chats)
      |> maybe_put("likes", likes)
      |> maybe_put("matches", matches)
      |> maybe_put_with_empty_list("feed", feed)
      |> maybe_put_with_empty_list("feed_categories", feed_categories)

    {:ok, reply,
     assign(socket, feed_filter: feed_filter, location: location, gender: gender, mode: :normal)}
  end

  def handle_in("fetch-category", %{"category" => category}, socket) do
    %{
      current_user: user,
      screen_width: screen_width,
      version: version,
      feed_filter: feed_filter,
      gender: gender,
      location: location
    } = socket.assigns

    feed =
      fetch_feed(user.id, location, gender, feed_filter, version, screen_width, true, category)

    {:reply, {:ok, %{"feed" => feed}}, socket}
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

    category = params["category"] || "recommended"

    feed =
      fetch_feed(user.id, location, gender, feed_filter, version, screen_width, false, category)

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

  # TODO remove
  def handle_in("seen-match", _params, socket) do
    {:reply, :ok, socket}
  end

  # TODO remove
  def handle_in("seen-like", _params, socket) do
    {:reply, :ok, socket}
  end

  # TODO remove
  def handle_in("reached-limit", _params, socket) do
    {:reply, :ok, socket}
  end

  # TODO remove
  def handle_in("like", _params, socket) do
    alert =
      alert(
        dgettext("alerts", "Deprecation warning"),
        dgettext("alerts", "Your app version is no longer supported, please upgrade.")
      )

    {:reply, {:error, %{alert: alert}}, socket}
  end

  # TODO remove
  def handle_in("decline", _params, socket) do
    alert =
      alert(
        dgettext("alerts", "Deprecation warning"),
        dgettext("alerts", "Your app version is no longer supported, please upgrade.")
      )

    {:reply, {:error, %{alert: alert}}, socket}
  end

  def handle_in("decline-invitation", %{"from_user_id" => from_user_id}, socket) do
    Chats.delete_chat(me_id(socket), from_user_id)
    {:reply, :ok, socket}
  end

  def handle_in("delete-chat", %{"with_user_id" => with_user_id}, socket) do
    Chats.delete_chat(me_id(socket), with_user_id)
    {:reply, :ok, socket}
  end

  # TODO remove
  def handle_in("unmatch", _params, socket) do
    alert =
      alert(
        dgettext("alerts", "Deprecation warning"),
        dgettext("alerts", "Your app version is no longer supported, please upgrade.")
      )

    {:reply, {:error, %{alert: alert}}, socket}
  end

  def handle_in("report", params, socket) do
    report(socket, params)
  end

  # TODO remove
  def handle_in("send-interaction", _params, socket) do
    alert =
      alert(
        dgettext("alerts", "Deprecation warning"),
        dgettext("alerts", "Your app version is no longer supported, please upgrade.")
      )

    {:reply, {:error, %{alert: alert}}, socket}
  end

  # messages

  def handle_in("send-message", %{"to_user_id" => to_user_id, "message" => message}, socket) do
    %{current_user: %{id: from_user_id}, screen_width: screen_width} = socket.assigns

    case Chats.save_message(to_user_id, from_user_id, message) do
      {:ok, message} ->
        {:reply, {:ok, %{"message" => render_message(message, screen_width)}}, socket}

      {:error, _changeset} ->
        {:reply, :error, socket}
    end
  end

  # TODO remove
  def handle_in("seen-interaction", _params, socket) do
    {:reply, :ok, socket}
  end

  def handle_in("seen-message", %{"message_id" => message_id}, socket) do
    %{current_user: %{id: by_user_id}} = socket.assigns

    reply = Chats.mark_message_seen(by_user_id, message_id)
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
  def handle_info({Chats, :deleted_chat, with_user_id}, socket) when is_binary(with_user_id) do
    push(socket, "deleted_chat", %{"with_user_id" => with_user_id})
    {:noreply, socket}
  end

  def handle_info({Chats, :chat, %Chat{user_id_1: uid1, user_id_2: uid2} = chat}, socket) do
    %{screen_width: screen_width, version: version, location: location} = socket.assigns

    [mate] = [uid1, uid2] -- [me_id(socket)]

    if profile = Feeds.get_mate_feed_profile(mate, location) do
      push(socket, "chat", %{
        "chat" => render_chat(%Chat{chat | profile: profile}, version, screen_width)
      })
    end

    {:noreply, socket}
  end

  def handle_info({Chats, :message, %Message{from_user_id: from_user_id} = message}, socket) do
    %{screen_width: screen_width} = socket.assigns

    push(socket, "message", %{
      "from_user_id" => from_user_id,
      "message" => render_message(message, screen_width)
    })

    {:noreply, socket}
  end

  def handle_info({Chats, :chat_match, users}, socket) do
    %{screen_width: screen_width, version: version, location: location} = socket.assigns

    [mate] = users -- [me_id(socket)]

    if profile = Feeds.get_mate_feed_profile(mate, location) do
      push(socket, "chat_match", %{
        "profile" =>
          render_chat_match_profile(%{
            profile: profile,
            version: version,
            screen_width: screen_width
          })
      })
    end

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

  defp fetch_feed(
         user_id,
         location,
         gender,
         feed_filter,
         version,
         screen_width,
         first_fetch,
         category
       ) do
    feed_reply = Feeds.fetch_feed(user_id, location, gender, feed_filter, first_fetch, category)
    render_feed(feed_reply, version, screen_width)
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

  # TODO remove
  defp render_likes(likes, version, screen_width) do
    Enum.map(likes, fn %{profile: profile, seen: seen} ->
      profile
      |> render_feed_item(version, screen_width)
      |> maybe_put("seen", seen)
    end)
  end

  # TODO remove
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

  defp render_chats(chats, version, screen_width) do
    Enum.map(chats, fn chat -> render_chat(chat, version, screen_width) end)
  end

  # TODO remove
  defp render_match(assigns) do
    render(MatchView, "match.json", assigns)
  end

  defp render_chat(chat, version, screen_width) do
    %Chat{
      id: chat_id,
      inserted_at: inserted_at,
      profile: profile,
      messages: messages,
      matched: matched
    } = chat

    assigns = %{
      id: chat_id,
      inserted_at: inserted_at,
      profile: profile,
      screen_width: screen_width,
      version: version,
      messages: messages,
      matched: matched
    }

    render(ChatView, "chat.json", assigns)
  end

  defp render_chat_match_profile(assigns) do
    render(FeedView, "feed_profile_with_distance.json", assigns)
  end

  defp render_message(message, screen_width) do
    render(ChatView, "message.json", message: message, screen_width: screen_width)
  end

  defp render_news(news, version, screen_width) do
    Enum.map(news, fn %{story: story} = news ->
      %{news | story: ViewHelpers.postprocess_story(story, version, screen_width, :feed)}
    end)
  end
end
