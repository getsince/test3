defmodule T.Feeds.FeedCache do
  @moduledoc false
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @session2profiles :session2profiles
  @profiles :profiles

  @genders ["M", "F", "N"]

  @impl true
  def init(_opts) do
    for my_gender <- @genders, want_gender <- @genders do
      :ets.new(table(my_gender, want_gender), [:named_table, :ordered_set])
    end

    # TODO compare perf with duplicate_bag (~10% faster)
    :ets.new(@session2profiles, [:named_table])
    :ets.new(@profiles, [:named_table])

    {:ok, nil}
  end

  @spec table(String.t(), String.t()) :: atom
  defp table(my_gender, want_gender)

  for g1 <- @genders, g2 <- @genders do
    defp table(unquote(g1), unquote(g2)), do: unquote(:"active_#{g2}#{g1}")
    defp table(unquote(g1 <> g2)), do: unquote(:"active_#{g1}#{g2}")
    defp table_id(unquote(:"active_#{g1}#{g2}")), do: unquote(g1 <> g2)
  end

  # def compress_story([page | rest]) do
  #   [encode_background(page) <> encode_size(page) <> encode_labels(page) | compress_story(rest)]
  # end

  # def compress_story([]), do: []

  # defp encode_background(%{"background" => %{"s3_key" => s3_key}}), do: <<1, Ecto.UUID.dump!(s3_key)::16-bytes>>
  # defp encode_background(%{"background" => %{"color" => color}}), do: <<0, color::16-bytes>>

  # defp encode_size(%{"size" => [h, w]}), do: <<0, h::64, w::64>>
  # defp encode_labels(%{"labels" => labels}) do
  #   Enum.reduce(labels, <<>>, fn label, acc ->
  #     acc <> Enum.reduce(label, <<>>, fn field, acc ->
  #       case field do
  #         {"question", val} -> acc <> <<>>
  #         {"answer", val} -> acc <> <<0::4, ::>>
  #       end
  #     end)
  #   end)
  # end

  @type feed_item :: {<<_::128>>, String.t(), String.t(), [map]}

  @max128 <<255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255>>

  @spec feed_init(String.t(), [String.t()], pos_integer, MapSet.t(<<_::128>>)) ::
          {binary, [feed_item]}
  def feed_init(gender, preferences, limit, filter)

  def feed_init(gender, [gender_pref], limit, filter) do
    fetch_feed(table(gender, gender_pref), @max128, limit, filter, _acc = [])
  end

  def feed_init(gender, [p1, p2], limit, filter) do
    fetch_feed_cycle(
      [table(gender, p1), table(gender, p2)],
      _next_tables = [],
      _cursors = [@max128, @max128],
      _next_cursors = [],
      limit,
      filter,
      _ended = [],
      _acc = []
    )
  end

  def feed_init(gender, [p1, p2, p3], limit, filter) do
    fetch_feed_cycle(
      [table(gender, p1), table(gender, p2), table(gender, p3)],
      _next_tables = [],
      [@max128, @max128, @max128],
      _next_cursors = [],
      limit,
      filter,
      _ended = [],
      _acc = []
    )
  end

  @spec feed_cont(binary, pos_integer, MapSet.t(<<_::128>>)) :: {binary, [feed_item]} | :error
  def feed_cont(cursor, limit, filter)

  def feed_cont(<<tab_id::2-bytes, cursor::128-bits>>, limit, filter) do
    fetch_feed(table(tab_id), cursor, limit, filter, _acc = [])
  end

  def feed_cont(<<t1::2-bytes, c1::128-bits, t2::2-bytes, c2::128-bits>>, limit, filter) do
    fetch_feed_cycle([table(t1), table(t2)], [], [c1, c2], [], limit, filter, [], _acc = [])
  end

  def feed_cont(
        <<t1::2-bytes, c1::128-bits, t2::2-bytes, c2::128-bits, t3::2-bytes, c3::128-bits>>,
        limit,
        filter
      ) do
    fetch_feed_cycle(
      [table(t1), table(t2), table(t3)],
      _next_tables = [],
      [c1, c2, c3],
      _next_cursors = [],
      limit,
      filter,
      _ended = [],
      _acc = []
    )
  end

  def feed_cont(_cursor, _limit, _filter) do
    :error
  end

  defp fetch_feed(tab, cursor, limit, filter, acc) when limit > 0 do
    case :ets.prev(tab, cursor) do
      <<session_id::128-bits>> = cursor ->
        if profile = fetch_feed_profile(session_id, filter) do
          fetch_feed(tab, cursor, limit - 1, filter, [profile | acc])
        else
          fetch_feed(tab, cursor, limit, filter, acc)
        end

      :"$end_of_table" ->
        {table_id(tab) <> cursor, postprocess_feed(acc, [])}
    end
  end

  defp fetch_feed(tab, cursor, 0, _filter, acc) do
    {table_id(tab) <> cursor, postprocess_feed(acc, [])}
  end

  defp fetch_feed_cycle([t | ts], next_ts, [c | cs], next_cs, limit, filter, ended, acc)
       when limit > 0 do
    case :ets.prev(t, c) do
      <<session_id::16-bytes>> = c ->
        if profile = fetch_feed_profile(session_id, filter) do
          acc = [profile | acc]
          fetch_feed_cycle(ts, [t | next_ts], cs, [c | next_cs], limit - 1, filter, ended, acc)
        else
          fetch_feed_cycle(ts, [t | next_ts], cs, [c | next_cs], limit, filter, ended, acc)
        end

      :"$end_of_table" ->
        fetch_feed_cycle(ts, next_ts, cs, next_cs, limit, filter, [{t, c} | ended], acc)
    end
  end

  defp fetch_feed_cycle([], [], [], [], _limit, _filter, ended, acc) do
    cursor = Enum.reduce(ended, <<>>, fn {tab, cursor}, acc -> acc <> table_id(tab) <> cursor end)
    {cursor, postprocess_feed(acc, [])}
  end

  defp fetch_feed_cycle([], ts, [], cs, limit, filter, ended, acc) do
    fetch_feed_cycle(ts, [], cs, [], limit, filter, ended, acc)
  end

  defp fetch_feed_cycle(ts, next_ts, cs, next_cs, 0, _filter, ended, acc) do
    tabs = Enum.zip(ts, cs) ++ Enum.zip(next_ts, next_cs) ++ ended
    cursor = Enum.reduce(tabs, <<>>, fn {tab, cursor}, acc -> acc <> table_id(tab) <> cursor end)
    {cursor, postprocess_feed(acc, [])}
  end

  @spec postprocess_feed([{binary, String.t(), String.t(), binary}], acc) :: acc
        when acc: [feed_item]
  defp postprocess_feed([{_, _, _, story} = profile | rest], acc) do
    # postprocess_feed(rest, [put_elem(profile, 3, :erlang.binary_to_term(story)) | acc])
    postprocess_feed(rest, [profile | acc])
  end

  defp postprocess_feed([], acc), do: acc

  @spec fetch_feed_profile(<<_::128>>, MapSet.t(<<_::128>>)) ::
          {<<_::128>>, String.t(), String.t(), binary} | nil
  defp fetch_feed_profile(<<_::128>> = session_id, filter) do
    [{^session_id, user_id}] = :ets.lookup(@session2profiles, session_id)

    unless MapSet.member?(filter, user_id) do
      [{^user_id, _name, _gender, _story} = profile] = :ets.lookup(@profiles, user_id)
      profile
    end
  end

  @spec put_user(<<_::128>>, <<_::128>>, map) :: :ok
  def put_user(<<_::128>> = user_id, <<_::128>> = session_id, data) do
    data =
      Map.update!(data, :story, fn [%{} | _rest] = story ->
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
    delete_session(session_id)
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

  # TODO improve, only delete from tables that have the user, need to know gender preferences
  defp delete_session(session_id) do
    for g1 <- @genders,
        g2 <- @genders,
        do: :ets.delete(table(g1, g2), session_id)
  end
end
