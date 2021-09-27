defmodule TWeb.AdminChannel do
  use TWeb, :channel
  alias T.Accounts

  @impl true
  def join("admin", _params, socket) do
    if Accounts.is_admin?(socket.assigns.current_user) do
      %{screen_width: screen_width} = socket.assigns
      profiles = Accounts.admin_list_profiles_ordered_by_activity()
      {:ok, %{"profiles" => render_profiles(profiles, screen_width)}, socket}
    else
      {:error, %{"error" => "forbidden"}}
    end
  end

  @impl true
  def handle_in("refresh", _params, socket) do
    %{screen_width: screen_width} = socket.assigns
    profiles = Accounts.admin_list_profiles_ordered_by_activity()
    {:reply, {:ok, %{"profiles" => render_profiles(profiles, screen_width)}}, socket}
  end

  defp render_profiles(profiles, screen_width) do
    Enum.map(profiles, fn profile ->
      render(TWeb.FeedView, "feed_profile.json", profile: profile, screen_width: screen_width)
    end)
  end
end
