defmodule T.CallTopics do
  use GenServer

  @table_name :call_topics

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_init_state) do
    call_topics_pid = :ets.new(@table_name, [:set, read_concurrency: true])

    locales = ["ru", "en"]

    for locale <- locales do
      {:ok, raw_topics} = File.read("priv/call_topics/#{locale}.txt")
      topics = String.split(raw_topics, "\n", trim: true)

      :ets.insert(call_topics_pid, {locale, topics})
    end

    {:ok, call_topics_pid}
  end

  def locale_topics(key) do
    GenServer.call(__MODULE__, {:find, key})
  end

  def handle_call({:find, key}, _from, pid) do
    {_, result} = :ets.lookup(pid, key) |> Enum.at(0)

    {:reply, result, pid}
  end
end
