defmodule TWeb.ModalComponent do
  use TWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="fixed top-0 left-0 w-full h-full overflow-auto opacity-100 phx-modal"
      phx-capture-click="close"
      phx-window-keydown="close"
      phx-key="escape"
      phx-target={"##{@id}"}
      phx-page-loading>

      <div class="mt-10 max-w-2xl mx-auto rounded border dark:border-gray-600 bg-white dark:bg-gray-800 overflow-hidden">
        <div class="flex items-center justify-between p-4 bg-gray-100 dark:bg-gray-700 border-b dark:border-gray-600">
          <span class="text-2xl font-bold"><%= @title %></span>
          <%= live_patch "✕", to: @return_to %>
        </div>

        <%= live_component @component, @opts %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("close", _, socket) do
    {:noreply, push_patch(socket, to: socket.assigns.return_to)}
  end
end
