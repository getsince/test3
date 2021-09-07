defmodule TWeb.ActiveSessionLive.SessionForm do
  use TWeb, :live_component

  @impl true
  def render(assigns) do
    ~L"""
    <div class="dark:bg-gray-800">
      <%= f = form_for :session, "#", phx_submit: "activate-session", class: "p-4" %>
        <%= if not Enum.empty?(@user_options) do %>
          <div class="mb-4">
            <%= label f, :user_id, "Pick a user to impersonate", class: "text-sm" %>
            <%= select f, :user_id, @user_options, class: "mt-1 dark:bg-gray-900 border-gray-200 dark:border-gray-700 bg-gray-100 block rounded", prompt: "Pick one" %>
            <%= error_tag f, :user_id %>
          </div>
        <% end %>

        <div>
          <%= label f, :duration, "Duration (minutes)", class: "text-sm" %>
          <%= number_input f, :duration, placeholder: "60", value: 60, class: "mt-1 border-gray-200 dark:bg-gray-900 dark:border-gray-700 bg-gray-100 block rounded" %>
          <%= error_tag f, :duration %>
        </div>

        <%= submit "Activate", class: "mt-4 border rounded transition px-4 h-10 dark:border-gray-700 hover:bg-gray-700" %>
      </form>
    </div>
    """
  end
end
