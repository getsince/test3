:active_sessions = :ets.new(:active_sessions, [:named_table, :ordered_set])

{time, _result} =
  :timer.tc(fn ->
    Enum.each(1..10_000, fn i ->
      :ets.insert(:active_sessions, {i, %{"user" => "info"}})
    end)
  end)

:active_sessions2 = :ets.new(:active_sessions2, [:named_table, :ordered_set])

{time, ids} =
  :timer.tc(fn ->
    Enum.map(1..10_000, fn _ ->
      {:ok, id} = Bigflake.mint()
      :ets.insert(:active_sessions2, {id})
      id
    end)
  end)

defmodule ActiveSessions do
  def more1(after_id, limit \\ 30) when is_integer(after_id) do
    {ids, _} = :ets.select(:active_sessions2, [{:"$1", [{:>, :"$1", after_id}], [:"$1"]}], limit)

    ids
  end

  def more2(after_id, limit \\ 30) when is_integer(after_id) do
    {ids, _} =
      :ets.select(:active_sessions2, [{{:"$1"}, [{:>, :"$1", after_id}], [:"$1"]}], limit)

    Enum.map(ids, fn id -> Bigflake.Base62.encode(id) end)
  end
end

id = Enum.at(ids, 5000)
IO.puts("inserted in #{time / 1000} ms")

match_spec = fn cursor ->
  [{{:"$1", :"$2"}, [{:>, :"$1", cursor}], [:_]}]
end

match_spec2 = fn cursor ->
  [{:"$1", [{:>, :"$1", cursor}], [:"$1"]}]
end

Benchee.run(%{
  # "ets.lookup" => fn -> :ets.lookup(:active_sessions, 5000) end,
  # "ets.select 10" => fn ->
  #   :ets.select(:active_sessions, match_spec.(5000), 10)
  # end,
  # "ets.select 30" => fn ->
  #   :ets.select(:active_sessions, match_spec.(5000), 30)
  # end,
  # "ets.select2 30" => fn ->
  #   :ets.select(:active_sessions2, match_spec2.(uuid), 30)
  # end,
  "ActiveSessions.more1" => fn ->
    ActiveSessions.more1(id)
  end,
  "ActiveSessions.more2" => fn ->
    ActiveSessions.more2(id)
  end
})
