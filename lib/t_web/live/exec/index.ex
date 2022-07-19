defmodule TWeb.ExecLive.Index do
  use TWeb, :live_view
  alias T.AlgoExec

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-2 flex flex-col min-h-screen">
      <button phx-click="run" class={"bg-green-800 rounded p-2 font-bold " <> if(@running?, do: "opacity-75 cursor-wait", else: "hover:bg-green-700 transition")} disabled={@running?}><%= if @running? do %>Running...<% else %>Run<% end %></button>

      <div id="log" class="mt-2 dark:bg-blue-900 text-white p-4 rounded flex-grow overflow-auto" phx-update="append">
        <%= for line <- @log do %>
          <pre id={"line-#{:os.system_time}"}><%= line %></pre>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    socket = assign(socket, running?: false)
    {:ok, socket, temporary_assigns: [log: []]}
  end

  @impl true
  def handle_event("run", _params, socket) do
    socket =
      if socket.assigns.running? do
        socket
      else
        AlgoExec.run(subscribe: self())
        assign(socket, running?: true)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({AlgoExec, :message, message}, socket) do
    {:noreply, assign(socket, log: [message])}
  end
end
