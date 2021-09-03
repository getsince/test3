:active_sessions =
  :ets.new(:active_sessions, [:named_table, :ordered_set, read_concurrency: true])

set = Discord.SortedSet.new()

# :active_sessions1 = :ets.new(:active_sessions1, [:named_table, :ordered_set])
# :active_sessions2 = :ets.new(:active_sessions2, [:named_table, :ordered_set])

# https://github.com/discord/sorted_set_nif

{time, ids} =
  :timer.tc(fn ->
    Enum.map(1..1_000, fn _ ->
      {:ok, id} = Bigflake.mint()
      :ets.insert(:active_sessions, {id})
      Discord.SortedSet.add(set, Bigflake.Base62.encode(id))
      id
    end)
  end)

id_100 = Enum.at(ids, 100)
# id_5000 = Enum.at(ids, 5000)
# id_50000 = Enum.at(ids, 50000)
# id_95000 = Enum.at(ids, 95000)

IO.puts("inserted in #{time / 1000} ms")

# {time, ids} =
#   :timer.tc(fn ->
#     Enum.map(1..10_000, fn i ->
#       {:ok, id} = Bigflake.mint()

#       if rem(i, 2) == 1 do
#         :ets.insert(:active_sessions1, {id})
#       else
#         :ets.insert(:active_sessions2, {id})
#       end

#       id
#     end)
#   end)

# id2 = Enum.at(ids, 5000)
# IO.puts("inserted2 in #{time / 1000} ms")

defmodule ActiveSessions do
  # def more2(after_id, limit \\ 30) when is_integer(after_id) do
  #   {ids1, _} = :ets.select(:active_sessions1, [{{:"$1"}, [{:>, :"$1", after_id}], [:"$1"]}], 15)
  #   {ids2, _} = :ets.select(:active_sessions2, [{{:"$1"}, [{:>, :"$1", after_id}], [:"$1"]}], 15)
  #   ids1 ++ ids2
  # end

  @spec more3(pos_integer, pos_integer) :: [pos_integer]
  def more3(after_id, count) when count > 0 do
    case :ets.next(:active_sessions, after_id) do
      id when is_integer(id) -> [id | more3(id, count - 1)]
      :"$end_of_table" -> []
    end
  end

  def more3(_after_id, 0) do
    []
  end

  # def more(after_id, limit \\ 30) when is_integer(after_id) do
  #   {ids, _} = :ets.select(:active_sessions, [{{:"$1"}, [{:>, :"$1", after_id}], [:"$1"]}], limit)

  #   ids
  # end
end

Benchee.run(
  %{
    # "ActiveSessions.more" => fn -> ActiveSessions.more(id1) end,
    # "ActiveSessions.more2" => fn -> ActiveSessions.more2(id2) end,
    # "lookup" => fn -> :ets.lookup(:active_sessions, id1) end,
    # "ActiveSessions.more3 count=30" => fn -> ActiveSessions.more3(id1, 30) end,
    "ActiveSessions.more3 count=10 id=100th" => fn -> ActiveSessions.more3(id_100, 10) end,
    "SortedSet count=10 at=100" => fn -> Discord.SortedSet.slice(set, 100, 10) end
    # "ActiveSessions.more3 count=10 id=5000th" => fn -> ActiveSessions.more3(id_5000, 10) end,
    # "ActiveSessions.more3 count=10 id=50000th" => fn -> ActiveSessions.more3(id_50000, 10) end,
    # "ActiveSessions.more3 count=10 id=95000th" => fn -> ActiveSessions.more3(id_95000, 10) end
  },
  parallel: 1
)
