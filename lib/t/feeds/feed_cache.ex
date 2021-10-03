defmodule FeedCache do
  use GenServer
  require Logger

  # def compress_story([%{"background" => %"s3_key" => key} | rest]) do
  #   s3_key = Ecto.UUID.dump!(s3_key)

  # end

  # def compress_story([]) do
  #   <<>>
  # end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @session2profiles :session2profiles
  @profiles :profiles

  @impl true
  def init(_opts) do
    for my_gender <- ["M", "F"], want_gender <- ["M", "F"] do
      :ets.new(table(my_gender, want_gender), [:named_table, :ordered_set])
    end

    # TODO compare perf with duplicate_bag (~10% faster)
    :ets.new(@session2profiles, [:named_table])
    :ets.new(@profiles, [:named_table])

    {:ok, nil}
  end

  def table(my_gender, want_gender)
  def table("M", "F"), do: :active_FM
  def table("F", "M"), do: :active_MF
  def table("M", "M"), do: :active_MM
  def table("F", "F"), do: :active_FF

  @spec fetch_feed(binary, String.t(), [String.t()], pos_integer()) ::
          {binary, [{binary, String.t(), String.t(), [map]}]}
  def fetch_feed(cursor \\ nil, gender, preferences, limit \\ 10)

  # with cursor and single gender preference
  def fetch_feed(<<_::192>> = cursor, gender, [preference], limit) do
    do_fetch_feed(table(gender, preference), cursor, limit, _acc = [])
  end

  # with two cursors and two gender preferences
  def fetch_feed(<<c1::24-bytes, c2::24-bytes>>, gender, [p1, p2], limit) do
    do_fetch_feed_2(0, table(gender, p1), table(gender, p2), c1, c2, limit, _acc = [])
  end

  # with no cursor and single gender preference
  def fetch_feed(nil = _cursor, gender, [preference], limit) do
    do_fetch_feed(table(gender, preference), _cursor = <<0::192>>, limit, _acc = [])
  end

  defp do_fetch_feed(tab, cursor, limit, acc) when limit > 0 do
    case :ets.next(tab, cursor) do
      <<session_id::16-bytes>> = cursor ->
        do_fetch_feed(tab, cursor, limit - 1, [fetch_feed_profile(session_id) | acc])

      :"$end_of_table" ->
        {cursor, :lists.reverse(acc)}
    end
  end

  defp do_fetch_feed(_tab, cursor, 0, acc) do
    {cursor, :lists.reverse(acc)}
  end

  defp do_fetch_feed_2(0, t1, t2, c1, c2, limit, acc) when limit > 0 do
    case :ets.next(t1, c1) do
      <<session_id::16-bytes>> = cursor ->
        do_fetch_feed_2(1, t1, t2, cursor, c2, limit - 1, [fetch_feed_profile(session_id) | acc])

      :"$end_of_table" ->
        do_fetch_feed_2_ended(0, t1, t2, c1, c2, limit, acc)
    end
  end

  defp do_fetch_feed_2(1, t1, t2, c1, c2, limit, acc) when limit > 0 do
    case :ets.next(t2, c2) do
      <<session_id::16-bytes>> = cursor ->
        do_fetch_feed_2(0, t1, t2, c1, cursor, limit - 1, [fetch_feed_profile(session_id) | acc])

      :"$end_of_table" ->
        do_fetch_feed_2_ended(1, t1, t2, c1, c2, limit, acc)
    end
  end

  defp do_fetch_feed_2(_turn, _t1, _t2, c1, c2, 0, acc) do
    {c1 <> c2, :lists.reverse(acc)}
  end

  # t1 ended
  defp do_fetch_feed_2_ended(0, _t1, t2, c1, c2, limit, acc) do
    {c2, acc2} = do_fetch_feed(t2, c2, limit, _acc = [])
    {c1 <> c2, :lists.reverse(acc) ++ acc2}
  end

  # t2 ended
  defp do_fetch_feed_2_ended(1, t1, _t2, c1, c2, limit, acc) do
    {c1, acc2} = do_fetch_feed(t1, c1, limit, _acc = [])
    {c1 <> c2, :lists.reverse(acc) ++ acc2}
  end

  defp do_fetch_feed_cycle(
         [tab | rest_tab],
         orig_tables,
         [cursor | rest_cursor],
         cursors,
         limit,
         acc
       )
       when limit > 0 do
    case :ets.next(tab, cursor) do
      <<_geohash::64, session_id::16-bytes>> = cursor ->
        acc = [fetch_feed_profile(session_id) | acc]
        # TODO I don't like ++
        do_fetch_feed_cycle(rest_tab, orig_tables, rest_cursor ++ [cursor], limit, acc)

      :"$end_of_table" ->
        do_fetch_feed_cycle(rest_tab, List.delete(orig_tables, tab), rest_cursor, limit, acc)
    end
  end

  defp do_fetch_feed_cycle([], _tables, [], _limit, acc) do
    {_cursors = <<>>, acc}
  end

  defp do_fetch_feed_cycle(_tables, _tables, _cursors, 0, acc) do
    {_cursors = <<>>, :lists.reverse(acc)}
  end

  def fetch_feed_profile(<<_::128>> = session_id) do
    [{^session_id, user_id}] = :ets.lookup(@session2profiles, session_id)
    [{^user_id, _name, _gender, story} = profile] = :ets.lookup(@profiles, user_id)
    put_elem(profile, 3, :erlang.binary_to_term(story))
  end

  def fetch_feed_profile(<<_::288>> = session_id) do
    session_id
    |> Ecto.UUID.dump!()
    |> fetch_feed_profile()
  end

  def put_user(<<_::128>> = user_id, <<_::128>> = session_id, data) do
    GenServer.call(__MODULE__, {:put, user_id, session_id, data})
  end

  def put_many_users(users) do
    GenServer.call(__MODULE__, {:put, users})
  end

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
    for g1 <- ["M", "F"],
        g2 <- ["M", "F"],
        do: :ets.delete(table(g1, g2), <<0::64, session_id::bytes>>)

    [{^session_id, user_id}] = :ets.lookup(@session2profiles, session_id)
    :ets.delete(@session2profiles, session_id)
    :ets.delete(@profiles, user_id)

    {:reply, :ok, state}
  end

  def handle_call(message, _from, state) do
    Logger.error("unhandled message in FeedCache: " <> inspect(message))
    {:reply, {:error, :badarg}, state}
  end

  defp insert_user(<<_::128>> = user_id, <<_::128>> = session_id, data) do
    %{gender: gender, preferences: prefs, name: name, story: story} = data

    :ets.insert(@profiles, {user_id, name, gender, story})
    :ets.insert(@session2profiles, {session_id, user_id})
    for pref <- prefs, do: :ets.insert(table(pref, gender), {<<0::64, session_id::bytes>>})
  end
end
