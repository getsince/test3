defmodule TWeb.FeedChannel do
  use TWeb, :channel
  import TWeb.ChannelHelpers

  defp channel_mod(socket) do
    case version(socket) do
      %Version{major: 2} -> __MODULE__.V2
      %Version{major: 1} -> __MODULE__.V1
    end
  end

  @impl true
  def join(topic, params, socket) do
    channel_mod(socket).join(topic, params, socket)
  end

  @impl true
  def handle_in(event, params, socket) do
    channel_mod(socket).handle_in(event, params, socket)
  end

  @impl true
  def handle_info(message, socket) do
    channel_mod(socket).handle_info(message, socket)
  end
end
