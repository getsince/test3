defmodule T.Feeds.FeedCache do
  @moduledoc false
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @session2profiles :session2profiles
  @profiles :profiles

  @impl true
  def init(_opts) do
    for my_gender <- ["M", "F", "N"], want_gender <- ["M", "F", "N"] do
      :ets.new(table(my_gender, want_gender), [:named_table, :ordered_set])
    end

    # TODO compare perf with duplicate_bag (~10% faster)
    :ets.new(@session2profiles, [:named_table])
    :ets.new(@profiles, [:named_table])

    {:ok, nil}
  end

  defp table(my_gender, want_gender)
  defp table("M", "F"), do: :active_FM
  defp table("F", "M"), do: :active_MF
  defp table("M", "M"), do: :active_MM
  defp table("M", "N"), do: :active_NM
  defp table("F", "F"), do: :active_FF
  defp table("F", "N"), do: :active_NF
  defp table("N", "N"), do: :active_NN
  defp table("N", "F"), do: :active_FN
  defp table("N", "M"), do: :active_MN

  # defp table_name(:active_FM), do: "FM"
  # defp table_name(:active_MF), do: "MF"
  # defp table_name(:active_MM), do: "MM"
  # defp table_name(:active_NM), do: "NM"
  # defp table_name(:active_FF), do: "FF"
  # defp table_name(:active_NF), do: "NF"
  # defp table_name(:active_NN), do: "NN"
  # defp table_name(:active_FN), do: "FN"
  # defp table_name(:active_MN), do: "MN"

  # TODO add filters
  @spec fetch_feed(binary, String.t(), [String.t()], pos_integer()) ::
          {[{String.t(), binary}], [{binary, String.t(), String.t(), [map]}]}
  def fetch_feed(cursor \\ nil, gender, preferences, limit \\ 10)

  # with cursor and single gender preference
  def fetch_feed(<<_::128>> = cursor, gender, [preference], limit) do
    do_fetch_feed(table(gender, preference), cursor, limit, _acc = [])
  end

  # with two cursors and two gender preferences
  def fetch_feed(<<c1::128, c2::128>>, gender, [p1, p2], limit) do
    tables = [table(gender, p1), table(gender, p2)]
    cursors = [c1, c2]
    do_fetch_feed_cycle(tables, [], cursors, [], limit, [], _acc = [])
  end

  # with three cursors and three gender preferences
  def fetch_feed(<<c1::128, c2::128, c3::128>>, gender, [p1, p2, p3], limit) do
    tables = [table(gender, p1), table(gender, p2), table(gender, p3)]
    cursors = [c1, c2, c3]
    do_fetch_feed_cycle(tables, [], cursors, [], limit, [], _acc = [])
  end

  # with no cursor and single gender preference
  def fetch_feed(nil = _cursor, gender, [preference], limit) do
    do_fetch_feed(table(gender, preference), _cursor = <<0::128>>, limit, _acc = [])
  end

  # with no cursor and two gender preferences
  def fetch_feed(nil = _cursor, gender, [p1, p2], limit) do
    tables = [table(gender, p1), table(gender, p2)]
    cursors = [<<0::128>>, <<0::128>>]
    do_fetch_feed_cycle(tables, [], cursors, [], limit, [], [])
  end

  def fetch_feed(nil = _cursor, gender, [p1, p2, p3], limit) do
    tables = [table(gender, p1), table(gender, p2), table(gender, p3)]
    cursors = [<<0::128>>, <<0::128>>, <<0::128>>]
    do_fetch_feed_cycle(tables, [], cursors, [], limit, [], [])
  end

  defp do_fetch_feed(tab, cursor, limit, acc) when limit > 0 do
    case :ets.next(tab, cursor) do
      <<session_id::16-bytes>> = cursor ->
        do_fetch_feed(tab, cursor, limit - 1, [fetch_feed_profile(session_id) | acc])

      :"$end_of_table" ->
        {[{tab, cursor}], :lists.reverse(acc)}
    end
  end

  defp do_fetch_feed(tab, cursor, 0, acc) do
    {[{tab, cursor}], :lists.reverse(acc)}
  end

  defp do_fetch_feed_cycle([t | ts], next_ts, [c | cs], next_cs, limit, ended, acc)
       when limit > 0 do
    case :ets.next(t, c) do
      <<session_id::16-bytes>> = c ->
        acc = [fetch_feed_profile(session_id) | acc]
        do_fetch_feed_cycle(ts, [t | next_ts], cs, [c | next_cs], limit - 1, ended, acc)

      :"$end_of_table" ->
        do_fetch_feed_cycle(ts, next_ts, cs, next_cs, limit, [{t, c} | ended], acc)
    end
  end

  # all tables ended
  defp do_fetch_feed_cycle([], [], [], [], _limit, ended, acc) do
    {ended, :lists.reverse(acc)}
  end

  defp do_fetch_feed_cycle([], ts, [], cs, limit, ended, acc) do
    do_fetch_feed_cycle(ts, [], cs, [], limit, ended, acc)
  end

  defp do_fetch_feed_cycle(ts, next_ts, cs, next_cs, 0, ended, acc) do
    tables = Enum.zip(ts, cs) ++ Enum.zip(next_ts, next_cs) ++ ended
    {tables, :lists.reverse(acc)}
  end

  defp fetch_feed_profile(<<_::128>> = session_id) do
    [{^session_id, user_id}] = :ets.lookup(@session2profiles, session_id)
    [{^user_id, _name, _gender, story} = profile] = :ets.lookup(@profiles, user_id)
    put_elem(profile, 3, :erlang.binary_to_term(story))
  end

  @spec put_user(<<_::128>>, <<_::128>>, map) :: :ok
  def put_user(<<_::128>> = user_id, <<_::128>> = session_id, data) do
    data =
      Map.update!(data, :story, fn story when is_list(story) ->
        :erlang.term_to_binary(story)
      end)

    GenServer.call(__MODULE__, {:put, user_id, session_id, data})
  end

  @spec put_many_users([{<<_::128>>, <<_::128>>, map}]) :: :ok
  def put_many_users(users) do
    # TODO update story in each user to binary
    GenServer.call(__MODULE__, {:put, users})
  end

  @spec remove_session(<<_::128>>) :: :ok
  def remove_session(session_id) do
    GenServer.call(__MODULE__, {:remove, session_id})
  end

  def stats do
    %{
      profiles: :ets.info(@profiles)
    }
  end

  @impl true
  def handle_call({:put, <<_::128>> = user_id, <<_::128>> = session_id, data}, _from, state) do
    insert_user(user_id, session_id, data)
    {:reply, :ok, state}
  end

  def handle_call({:put, users}, _from, state) when is_list(users) do
    Enum.each(users, fn {user_id, session_id, data} -> insert_user(user_id, session_id, data) end)
    {:reply, :ok, state}
  end

  def handle_call({:remove, <<_::128>> = session_id}, _from, state) do
    # TODO improve, only delete from tables that have the user, need to know gender preferences
    for g1 <- ["M", "F", "N"],
        g2 <- ["M", "F", "N"],
        do: :ets.delete(table(g1, g2), session_id)

    [{^session_id, user_id}] = :ets.lookup(@session2profiles, session_id)
    :ets.delete(@session2profiles, session_id)
    :ets.delete(@profiles, user_id)

    {:reply, :ok, state}
  end

  def handle_call(message, _from, state) do
    Logger.error("unhandled message in #{__MODULE__}: " <> inspect(message))
    {:reply, {:error, :badarg}, state}
  end

  defp insert_user(<<_::128>> = user_id, <<_::128>> = session_id, data) do
    %{gender: gender, preferences: prefs, name: name, story: story} = data
    :ets.insert(@profiles, {user_id, name, gender, story})
    :ets.insert(@session2profiles, {session_id, user_id})
    for pref <- prefs, do: :ets.insert(table(pref, gender), {session_id})
  end
end
