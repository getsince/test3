defmodule TWeb.FeedChannel do
  use TWeb, :channel
  alias TWeb.ProfileView
  alias T.{Feeds, Matches, Accounts}

  @impl true
  def join("feed:" <> user_id, %{"timezone" => timezone}, socket) do
    ChannelHelpers.verify_user_id(socket, user_id)
    # ChannelHelpers.ensure_onboarded(socket)

    # TODO show who's online

    if match = Matches.get_current_match(user_id) do
      other_profile = Matches.get_other_profile_for_match!(match, user_id)
      # TODO close channel
      {:ok, %{match: render_match(match, other_profile)}, socket}
    else
      :ok = Feeds.subscribe(user_id)

      datetime = local_datetime_now(timezone)
      my_profile = Accounts.get_profile!(socket.assigns.current_user)
      feed = Feeds.get_or_create_feed(my_profile, DateTime.to_date(datetime))
      schedule_feed_refresh_at_midnight(datetime, timezone)

      {:ok, %{feed: render_profiles(feed)}, assign(socket, timezone: timezone)}
    end
  end

  defp local_datetime_now(timezone) do
    # |> IO.inspect(label: "now")
    DateTime.shift_zone!(DateTime.utc_now(), timezone)
  end

  defp mindnight_next_day(date, timezone) do
    # |> IO.inspect(label: "midnight next day")
    DateTime.new(date, Time.new!(0, 0, 0), timezone)
  end

  # TODO extract and test
  defp schedule_feed_refresh_at_midnight(datetime_now, timezone) do
    # |> IO.inspect(label: "next_day")
    next_day = datetime_now |> DateTime.to_date() |> Date.add(1)

    midnight_next_day =
      case mindnight_next_day(next_day, timezone) do
        {:ok, datetime} -> datetime
        {:ambiguous, _first_, second_dt} -> second_dt
        {:gap, _just_before, just_after} -> just_after
      end

    # |> IO.inspect(label: "diff")
    seconds_diff = DateTime.diff(midnight_next_day, datetime_now)

    Process.send_after(
      self(),
      {__MODULE__, [:update_feed], next_day},
      :timer.seconds(seconds_diff)
    )
  end

  defp render_match(match, profile) do
    %{
      id: match.id,
      profile: render_profile(profile)
    }
  end

  defp render_profile(profile) do
    render(ProfileView, "show.json", profile: profile)
  end

  defp render_profiles(profiles) do
    Enum.map(profiles, &render_profile/1)
  end

  @impl true
  def handle_in("like", %{"profile_id" => profile_id}, socket) do
    # verify_can_see_profile(socket, profile_id)
    user = socket.assigns.current_user
    {:ok, _} = Feeds.like_profile(user.id, profile_id)
    {:reply, :ok, socket}
  end

  def handle_in("dislike", %{"profile_id" => profile_id}, socket) do
    user = socket.assigns.current_user
    :ok = Feeds.dislike_profile(user.id, profile_id)
    {:reply, :ok, socket}
  end

  # TODO test
  def handle_in(
        "report",
        %{"report" => %{"reason" => reason, "profile_id" => reported_user_id}},
        socket
      ) do
    %{current_user: reporter} = socket.assigns

    case Accounts.report_user(reporter.id, reported_user_id, reason) do
      :ok ->
        {:reply, :ok, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:reply, {:error, %{report: render(ErrorView, "changeset.json", changeset: changeset)}},
         socket}
    end
  end

  @impl true
  def handle_info({Feeds, [:matched], match}, socket) do
    other_profile = Matches.get_other_profile_for_match!(match, socket.assigns.current_user.id)
    push(socket, "matched", %{match: render_match(match, other_profile)})
    {:noreply, socket}
  end

  # TODO test
  def handle_info({Matches, [:pending_match_activated], match}, socket) do
    other_profile = Matches.get_other_profile_for_match!(match, socket.assigns.current_user.id)
    push(socket, "matched", %{match: render_match(match, other_profile)})
    {:noreply, socket}
  end

  # TODO test
  def handle_info({__MODULE__, [:update_feed], date}, socket) do
    %{timezone: timezone, current_user: user} = socket.assigns

    profile = Accounts.get_profile!(user)
    feed = Feeds.get_or_create_feed(profile, date)
    schedule_feed_refresh_at_midnight(local_datetime_now(timezone), timezone)
    push(socket, "feed:update", %{feed: render_profiles(feed)})

    {:noreply, socket}
  end
end
