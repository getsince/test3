defmodule TWeb.ProfileLive.Index do
  use TWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 space-y-4">
    <%= for profile <- @profiles do %>
      <div class="p-2 rounded border bg-gray-50">
        <p class="font-bold"><%= profile.name %></p>
        <div class="flex space-x-2">
          <%= for s3_key <- s3_keys(profile.story) do %>
            <img src={s3_url(s3_key)} class="rounded border" style="width:300px;" />
          <% end %>
        </div>
      </div>
    <% end %>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, profiles: fetch_profiles())}
  end

  defp fetch_profiles do
    import Ecto.Query
    T.Accounts.Profile |> order_by(desc: :last_active) |> T.Repo.all()
  end

  defp s3_keys(_story = nil), do: []

  defp s3_keys(story) do
    story
    |> Enum.map(fn
      %{"background" => %{"s3_key" => s3_key}} -> s3_key
      %{"background" => _} -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp s3_url(s3_key) do
    T.Media.user_s3_url(s3_key)
  end
end
