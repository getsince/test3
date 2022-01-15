defmodule Sub do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    topic = Keyword.fetch!(opts, :topic)
    Phoenix.PubSub.subscribe(T.PubSub, topic)
    {:ok, nil}
  end

  @impl true
  def handle_info(_message, state) do
    {:noreply, state}
  end
end

Enum.each(1..200_000, fn _ -> Sub.start_link(topic: "topic") end)
Enum.each(1..10, fn _ -> Sub.start_link(topic: "topic2") end)

map = %{"some" => "key", "then" => "some oter key"}

Benchee.run(
  %{
    "message" => fn topic -> Phoenix.PubSub.broadcast(T.PubSub, topic, "message") end,
    "map" => fn topic -> Phoenix.PubSub.broadcast(T.PubSub, topic, map) end
  },
  inputs: %{"lots subs" => "topic", "few subs" => "topic2"}
)
