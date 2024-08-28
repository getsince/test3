defmodule SinceWeb.FeedChannel do
  use SinceWeb, :channel
  import SinceWeb.ChannelHelpers

  alias SinceWeb.{FeedView, ChatView, ViewHelpers, GameView}
  alias Since.{Feeds, Chats, Accounts, News, Todos, Games}
  alias Since.Chats.{Chat, Message}
  alias Since.Games.Compliment

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
        :ok = Games.subscribe_for_user(user_id)

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

    # TODO
    {old_location, gender, premium, hidden?} =
      Accounts.get_location_gender_premium_hidden?(user_id)

    location = socket.assigns.location || old_location
    %{screen_width: screen_width, version: version} = socket.assigns

    chats =
      user_id
      |> Chats.list_chats(location)
      |> render_chats(version, screen_width)

    compliments =
      user_id
      |> Games.list_compliments(location, premium)
      |> render_compliments(version, screen_width)

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

    meetings =
      case params["need_feed"] do
        true ->
          fetch_meetings(user_id, location, nil, version, screen_width)

        _ ->
          nil
      end

    game =
      case params["need_feed"] do
        true ->
          fetch_game(user_id, location, gender, feed_filter, version, screen_width)

        _ ->
          nil
      end

    reply =
      %{}
      |> maybe_put("news", news)
      |> maybe_put("todos", todos)
      |> maybe_put("chats", chats)
      |> maybe_put_with_empty_list("feed", feed)
      |> maybe_put_with_empty_list("feed_categories", feed_categories)
      |> maybe_put_with_empty_list("meetings", meetings)
      |> maybe_put("game", game)
      |> maybe_put("compliments", compliments)

    {:ok, reply,
     assign(socket,
       feed_filter: feed_filter,
       location: location,
       gender: gender,
       premium: premium,
       mode: :normal
     )}
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

  def handle_in("fetch-game", _params, socket) do
    %{
      current_user: user,
      screen_width: screen_width,
      version: version,
      feed_filter: feed_filter,
      gender: gender,
      location: location
    } = socket.assigns

    game = fetch_game(user.id, location, gender, feed_filter, version, screen_width)

    {:reply, {:ok, %{"game" => game}}, socket}
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

  @impl true
  def handle_in("more-meetings", %{"cursor" => cursor} = _params, socket) do
    %{
      current_user: user,
      screen_width: screen_width,
      version: version,
      location: location
    } = socket.assigns

    meetings = fetch_meetings(user.id, location, cursor, version, screen_width)

    {:reply, {:ok, %{"meetings" => meetings}}, socket}
  end

  # TODO possibly batch
  def handle_in("seen", %{"user_id" => user_id}, socket) do
    me = me_id(socket)
    %{mode: mode} = socket.assigns

    # if timings = params["timings"] do
    #   Events.save_seen_timings(:feed, me, user_id, timings)
    # end

    if mode == :normal, do: Feeds.mark_profile_seen(user_id, by: me)

    {:reply, :ok, socket}
  end

  def handle_in("seen", %{"news_story_id" => news_story_id}, socket) do
    News.mark_seen(me_id(socket), news_story_id)
    {:reply, :ok, socket}
  end

  # TODO deprecate
  def handle_in("decline-invitation", %{"from_user_id" => from_user_id}, socket) do
    Chats.delete_chat(me_id(socket), from_user_id)
    {:reply, :ok, socket}
  end

  def handle_in("delete-chat", %{"with_user_id" => with_user_id}, socket) do
    Chats.delete_chat(me_id(socket), with_user_id)
    {:reply, :ok, socket}
  end

  def handle_in("report", params, socket) do
    report(socket, params)
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

  def handle_in("seen-message", %{"message_id" => message_id}, socket) do
    %{current_user: %{id: by_user_id}} = socket.assigns

    reply = Chats.mark_message_seen(by_user_id, message_id)
    {:reply, reply, socket}
  end

  # compliments

  def handle_in(
        "send-compliment",
        %{"to_user_id" => to_user_id, "prompt" => prompt} = params,
        socket
      ) do
    %{
      current_user: user,
      screen_width: screen_width,
      version: version,
      feed_filter: feed_filter,
      gender: gender,
      location: location
    } = socket.assigns

    seen_ids = params["seen_ids"] || []

    case Games.save_compliment(to_user_id, user.id, prompt, seen_ids) do
      {:ok, %Compliment{} = compliment} ->
        {:reply,
         {:ok,
          %{
            "compliment" => render_compliment(compliment, version, screen_width),
            "game" => fetch_game(user.id, location, gender, feed_filter, version, screen_width)
          }}, socket}

      {:ok, %Chat{} = chat} ->
        if profile = Feeds.get_mate_feed_profile(to_user_id, location) do
          {:reply,
           {:ok,
            %{
              "chat" => render_chat(%{chat | profile: profile}, version, screen_width),
              "game" => fetch_game(user.id, location, gender, feed_filter, version, screen_width)
            }}, socket}
        end

      {:error, %DateTime{} = limit_expiration} ->
        {:reply, {:error, %{"limit_expiration" => limit_expiration}}, socket}

      {:error, _changeset} ->
        {:reply, :error, socket}
    end
  end

  def handle_in("seen-compliment", %{"compliment_id" => compliment_id}, socket) do
    %{current_user: %{id: by_user_id}} = socket.assigns

    reply = Games.mark_compliment_seen(by_user_id, compliment_id)
    {:reply, reply, socket}
  end

  def handle_in("like", %{"user_id" => to_user_id}, socket) do
    %{
      current_user: user,
      screen_width: screen_width,
      version: version,
      location: location
    } = socket.assigns

    # if timings = params["timings"] do
    #   Events.save_seen_timings(:feed, user.id, to_user_id, timings)
    # end

    case Games.save_compliment(to_user_id, user.id, "like") do
      {:ok, %Compliment{}} ->
        {:reply, :ok, socket}

      {:ok, %Chat{} = chat} ->
        if profile = Feeds.get_mate_feed_profile(to_user_id, location) do
          {:reply,
           {:ok,
            %{
              "chat" => render_chat(%{chat | profile: profile}, version, screen_width)
            }}, socket}
        end

      {:error, %DateTime{} = limit_expiration} ->
        {:reply, {:error, %{"limit_expiration" => limit_expiration}}, socket}

      {:error, _changeset} ->
        {:reply, :error, socket}
    end
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

  def handle_in("add-meeting", %{"data" => meeting_data}, socket) do
    %{
      current_user: %{id: user_id},
      version: version,
      screen_width: screen_width,
      location: location
    } = socket.assigns

    case Feeds.save_meeting(user_id, meeting_data) do
      {:ok, meeting} ->
        if profile = Feeds.get_mate_feed_profile(user_id, location) do
          {:reply,
           {:ok,
            %{"meeting" => render_meeting(%{meeting | profile: profile}, version, screen_width)}},
           socket}
        end

      {:error, _changeset} ->
        {:reply, :error, socket}
    end
  end

  def handle_in("delete-meeting", %{"id" => meeting_id}, socket) do
    %{current_user: %{id: user_id}} = socket.assigns

    reply = Feeds.delete_meeting(user_id, meeting_id)
    {:reply, reply, socket}
  end

  def handle_in("fetch-premium-compliments", _params, socket) do
    %{
      current_user: %{id: user_id},
      screen_width: screen_width,
      version: version,
      location: location
    } = socket.assigns

    Accounts.set_premium(user_id, true)

    compliments =
      Games.list_compliments(user_id, location, true) |> render_compliments(version, screen_width)

    {:reply, {:ok, %{"compliments" => compliments}}, assign(socket, premium: true)}
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
      has_private_page = profile.story |> Enum.any?(fn page -> Map.has_key?(page, "blurred") end)
      # TODO? refactor (logic shouldn't be in channel)
      if has_private_page, do: Chats.notify_private_page_available(me_id(socket), mate)

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

  def handle_info({Games, :compliment, %Compliment{} = compliment}, socket) do
    %{screen_width: screen_width, version: version} = socket.assigns

    push(socket, "compliment", %{
      "compliment" => render_compliment(compliment, version, screen_width)
    })

    {:noreply, socket}
  end

  def handle_info({Games, :chat, %Chat{user_id_1: uid1, user_id_2: uid2} = chat}, socket) do
    %{screen_width: screen_width, version: version, location: location} = socket.assigns

    [mate] = [uid1, uid2] -- [me_id(socket)]

    if profile = Feeds.get_mate_feed_profile(mate, location) do
      push(socket, "chat", %{
        "chat" => render_chat(%Chat{chat | profile: profile}, version, screen_width)
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

  defp fetch_meetings(user_id, location, cursor, version, screen_width) do
    meetings_reply = Feeds.fetch_meetings(user_id, location, cursor)
    render_meetings(meetings_reply, version, screen_width)
  end

  defp fetch_game(user_id, location, gender, feed_filter, version, screen_width) do
    game = Games.fetch_game(user_id, location, gender, feed_filter)
    render_game(game, version, screen_width)
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

  defp render_meetings(meetings, version, screen_width) do
    Enum.map(meetings, fn meeting -> render_meeting(meeting, version, screen_width) end)
  end

  defp render_chats(chats, version, screen_width) do
    Enum.map(chats, fn chat -> render_chat(chat, version, screen_width) end)
  end

  defp render_compliments(compliments, version, screen_width) do
    Enum.map(compliments, fn compliment ->
      render_compliment(compliment, version, screen_width)
    end)
  end

  defp render_game(nil = _game, _version, _screen_width), do: nil

  defp render_game(game, version, screen_width) do
    render(GameView, "game.json", game: game, version: version, screen_width: screen_width)
  end

  defp render_compliment(compliment, version, screen_width) do
    render(GameView, "compliment.json", %{
      id: compliment.id,
      prompt: compliment.prompt,
      profile: compliment.profile,
      seen: compliment.seen,
      inserted_at: compliment.inserted_at,
      version: version,
      screen_width: screen_width
    })
  end

  defp render_meeting(meeting, version, screen_width) do
    render(FeedView, "meeting.json",
      meeting: meeting,
      version: version,
      screen_width: screen_width
    )
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
    render(FeedView, "match_profile.json", assigns)
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
