defmodule TWeb.LogLive.Index do
  use TWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(T.PubSub, "logs")
    {:ok, assign(socket, logs: [], id: 0), temporary_assigns: [logs: []]}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="logs" phx-update="append" class="space-y-2 p-4" phx-hook="ScrollWindowDownHook">
      <%= for {id, log} <- @logs do %>
        <pre id={id} class={log_class(log)}><%= log_text(log) %></pre>
      <% end %>
    </div>
    """
  end

  @base_log_class "text-sm border rounded p-2 overflow-auto"

  defp log_class({level, _ts, _message}) do
    color =
      case level do
        :debug ->
          " text-blue-700 bg-blue-100 border-blue-500 dark:text-blue-200 dark:bg-blue-900 dark:border-blue-600"

        :info ->
          " text-gray-700 bg-gray-100 border-gray-500 dark:text-gray-200 dark:bg-gray-800 dark:border-gray-600"

        :warn ->
          " text-yellow-600 bg-yellow-100 border-yellow-500 dark:text-yellow-200 dark:bg-yellow-900 dark:border-yellow-700"

        :error ->
          " text-red-700 bg-red-100 border-red-500 dark:text-red-200 dark:bg-red-800 dark:border-red-600"
      end

    {:safe, [@base_log_class, color]}
  end

  defp log_text({_level, {_ymd, {h, m, s, ms}}, message}) do
    time = Time.new!(h, m, s, {ms * 1000, 3})
    [Time.to_iso8601(time), ": ", message]
  end

  @impl true
  def handle_info(log, socket) do
    {:noreply, add_log(socket, log)}
  end

  defp add_log(socket, {level, timestamp, message}) do
    id = socket.assigns.id
    assign(socket, logs: [{id, {level, timestamp, message}}], id: id + 1)
  end
end
