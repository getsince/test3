# taken from https://github.com/hexpm/hexpm/blob/171e840199e7248fdc3a30e6091b631cd80bb3d5/lib/hexpm_web/rate_limit_pub_sub.ex

defmodule TWeb.RateLimitPubSub do
  use GenServer
  alias TWeb.Plugs.Attack

  @pubsub T.PubSub
  @topic "ratelimit"

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def broadcast(key, time) do
    server = GenServer.whereis(__MODULE__)
    Phoenix.PubSub.broadcast_from!(@pubsub, server, @topic, {:throttle, key, time})
  end

  def init([]) do
    Phoenix.PubSub.subscribe(@pubsub, @topic)
    {:ok, []}
  end

  def handle_info({:throttle, {:user, user_id}, time}, []) do
    Attack.user_throttle(user_id, time: time)
    {:noreply, []}
  end

  def handle_info({:throttle, {:ip, ip}, time}, []) do
    Attack.ip_throttle(ip, time: time)
    {:noreply, []}
  end
end
