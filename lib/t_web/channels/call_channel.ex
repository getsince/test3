defmodule TWeb.CallChannel do
  use TWeb, :channel

  @impl true
  def join("call:" <> call_id, _params, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_in("peer-message", body, socket) do
    {:noreply, socket}
  end
end
