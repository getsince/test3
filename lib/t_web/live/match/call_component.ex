defmodule TWeb.MatchLive.CallComponent do
  use TWeb, :live_component

  @impl true
  def update(%{me: me, call: {_, mate}} = assigns, socket) do
    {:ok, socket |> assign(assigns) |> assign(initiator?: me < mate, mate: mate)}
  end

  defp start_webrtc?({s, _mate}) do
    s in [:picked_up]
  end

  defp show_hang_up?({s, _mate}) do
    s in [:called, :calling, :picked_up]
  end

  defp show_pick_up?({s, _mate}) do
    s in [:called]
  end
end
