defmodule TWeb.CallChannel do
  use TWeb, :channel
  alias TWeb.ChannelHelpers
  alias T.{Twilio}

  # TODO presence per call

  @impl true
  def join("call:" <> call_id, _params, socket) do
    # TODO verify call, check that current user is allowed
    # TOOD assign role to socket (inviter / invitee)
    # only invitee can pick up?

    # get call state, if it's ended, reply that it's ended
    # also reply with other user's feed item
    {:ok, socket}
  end

  @impl true
  def handle_in("peer-message", %{}, socket) do
    {:noreply, socket}
  end

  def handle_in("pick-up", _params, socket) do
    {:noreply, socket}
  end

  def handle_in("hang-up", _params, socket) do
    # mark call as hanged up
    # also when last user disconnects, call ends as well?
    {:noreply, socket}
  end

  def handle_in("ice-servers", _params, socket) do
    {:reply, {:ok, %{ice_servers: Twilio.ice_servers()}}, socket}
  end

  @impl true
  def handle_info(:after_join, socket) do
    # TODO track self
    # TODO possibly remove self from feed channel?
    {:noreply, socket}
  end
end
