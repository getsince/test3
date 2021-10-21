defmodule Dev do
  # click + -> can add session by picking user and inputting duration -> table updates
  # can select user to impersonate, if selected, can invite, call etc. based on status
  # search

  def devices do
    T.Accounts.APNSDevice
    |> T.Repo.all()
    |> Enum.map(fn device ->
      %{device | device_id: Base.encode16(device.device_id)}
    end)
  end
end

# defmodule ActiveSessionCache do
#   @moduledoc false
#   use GenServer

#   def start_link(opts) do
#     GenServer.start_link(__MODULE__, opts, name: __MODULE__)
#   end

#   @impl true
#   def init(opts) do
#     opts = [:named_table, :ordered_set]

#     :ets.new(:sessions_MF, opts)
#     :ets.new(:sessions_MM, opts)
#     :ets.new(:sessions_MN, opts)
#     :ets.new(:sessions_FF, opts)
#     :ets.new(:sessions_FM, opts)
#     :ets.new(:sessions_FN, opts)
#     :ets.new(:sessions_NF, opts)
#     :ets.new(:sessions_NM, opts)
#     :ets.new(:sessions_NN, opts)

#     {:continue, {:populate_cache, _state = nil}}
#   end

#   @impl true
#   def handle_continue(:populate_cache, state) do
#     {:ok, state}
#   end

#   # example cursor = %{"MF" => id, "M"}

#   # tables
#   # male who looks for female
#   # male who looks for male
#   # male who looks for non-binary
#   # female who looks for female
#   # female who looks for male
#   # female who looks for non-binary
#   # non-binary who looks for female
#   # non-binary who looks for male
#   # non-binary who looks for non-binary

#   #                                              F who looks for M
#   # I'm male who looks for female, I look into ["F",            "M"]
#   # I'm female who looks for male or female, I look into FF and MF

#   # simplified
#   # male who looks for female
#   # male who looks for male
#   # female who looks for female
#   # female who looks for male

#   defp table("MF"), do: :sessions_MF
#   defp table("FM"), do: :sessions_FM
#   defp table("FF"), do: :sessions_FF
#   defp table("MM"), do: :sessions_MM

#   def list_active_sessions(%{"FM" => 0}) do
#     next(:sessions_FM, _after = 0, _count = 10)
#   end

#   def next(table, after_id, count) when count > 0 do
#     case :ets.next(table, after_id) do
#       id when is_integer(id) -> [id | next(table, id, count - 1)]
#       :"$end_of_table" -> []
#     end
#   end

#   def next(_table, _after_id, 0), do: []

#   def list_active_sessions(cursor, count) do
#     for {table, last_id} <- cursor do
#       case :ets.next(table(table), last_id) do
#         id when is_integer(id) -> [id | nil]
#         :"$end_of_table" -> []
#       end
#     end
#   end
# end
