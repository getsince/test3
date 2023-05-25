defmodule TWeb.WorkflowLive.Index do
  use TWeb, :live_view
  alias T.{Workflows, FeedAI}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-2">
      <div class="text-center my-2">
        <button
          phx-click="start"
          class="rounded bg-green-300 text-green-700 border-green-700 border pl-1 pr-2 leading-7 font-semibold hover:bg-green-400 transition"
        >
          🚀 Start FeedAI workflow
        </button>
      </div>
      <div>
        <%= for {node, workflows} when map_size(workflows) > 0 <- @workflows do %>
          <h3 class="ml-3 p-1 text-lg font-semibold text-gray-500 dark:text-gray-400"><%= node %></h3>
          <ul class="p-2 space-y-2">
            <%= for {id, state} <- workflows do %>
              <li><.workflow id={id} state={state} /></li>
            <% end %>
          </ul>
        <% end %>
      </div>
    </div>
    """
  end

  defp workflow(assigns) do
    ~H"""
    <div class="p-2 inline-block rounded bg-gray-200 dark:bg-gray-600">
      <div class="text-sm flex justify-between">
        <div>
          <span class="font-semibold font-mono"><%= @id %></span>
          <span class="text-gray-700 dark:text-gray-300">
            started
            <span title={datetime(@id)} class="dark:text-white font-semibold">
              <%= ago(datetime(@id)) %>
            </span>
          </span>
        </div>
        <button
          phx-click="shutdown"
          phx-value-id={@id}
          class="ml-4 rounded bg-red-300 text-red-600 border-red-500 border px-1 leading-6 font-semibold uppercase hover:bg-red-400 transition"
          data-confirm={"Are you sure you want to shutdown #{@id}?"}
        >
          shutdown
        </button>
      </div>
      <div class="mt-2">
        <span class="text-sm dark:text-gray-300 text-gray-700">Workflow state:</span>
        <pre class="mt-1 p-2 text-sm rounded font-mono bg-gray-300 dark:bg-gray-700"><%= inspect(@state, pretty: true) %></pre>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Workflows.subscribe()
    {:ok, fetch_workflows(socket), temporary_assigns: [workflows: []]}
  end

  @impl true
  def handle_event("shutdown", %{"id" => workflow_id}, socket) do
    :ok = Workflows.primary_shutdown_workflow(workflow_id)
    {:noreply, socket}
  end

  def handle_event("start", _params, socket) do
    {:ok, _pid} = FeedAI.start_workflow()
    {:noreply, socket}
  end

  @impl true
  def handle_info({Workflows, _event, _data}, socket) do
    {:noreply, fetch_workflows(socket)}
  end

  defp fetch_workflows(socket) do
    workflows = Workflows.primary_list_running()
    assign(socket, workflows: workflows)
  end

  defp datetime(<<_::288>> = uuid) do
    datetime(Ecto.Bigflake.UUID.dump!(uuid))
  end

  defp datetime(<<unix::64, _rest::64>>) do
    unix |> DateTime.from_unix!(:millisecond) |> DateTime.truncate(:second)
  end

  defp ago(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime)

    cond do
      diff < 60 -> "less than a minute ago"
      diff < 2 * 60 -> "a minute ago"
      diff < 3600 -> "#{div(diff, 60)} minutes ago"
      diff < 2 * 3600 -> "an hour ago"
      diff < 24 * 3600 -> "#{div(diff, 3600)} hours ago"
      diff < 2 * 24 * 3600 -> "a day ago"
      diff < 7 * 24 * 3600 -> "#{div(diff, 24 * 3600)} days ago"
      true -> "more than a week ago, on #{DateTime.to_date(datetime)}"
    end
  end
end
