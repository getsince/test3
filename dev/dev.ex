defmodule Dev do
  # alias T.PushNotifications.APNS

  # click + -> can add session by picking user and inputting duration -> table updates
  # can select user to impersonate, if selected, can invite, call etc. based on status
  # search

  def args do
    %{
      "data" => %{
        "match_id" => "0000017b-b277-cbad-0242-ac1100020000"
      },
      "device_id" => "E069BD8A7CFF5BC34656C767209697AE3DB3B26E03E1252FA79EA7A773F75783",
      "env" => "sandbox",
      "locale" => nil,
      "template" => "timeslot_started",
      "topic" => "since.app.ios"
    }
  end

  def send_notification(args \\ args()) do
    T.PushNotifications.APNSJob.perform(%Oban.Job{args: args})
  end

  def run do
    # notifications =
    #   devices()
    #   |> Enum.map(fn device ->
    #     %Pigeon.APNS.Notification{
    #       device_token: device.device_id,
    #       push_type: "background",
    #       topic: "since.app.ios"
    #     }
    #   end)

    # Pigeon.APNS.push(notifications, to: :prod)

    # args = %{
    #   "data" => %{"name" => "Rail", "user_id" => "0000017b-86b5-039d-0242-ac1100020000"},
    #   "device_id" => "706e1db8abb8205351eefa0b5be078149f8f5f277a99dda0601bc8d8647a56cd",
    #   "env" => "sandbox",
    #   "locale" => nil,
    #   "template" => "invite",
    #   "topic" => "since.app.ios"
    # }

    devices = [
      "6ad0ce59461fc5a491a94bc012f03bc1c5e2c36ea6474f31ce419830e09b95f7",
      "706e1db8abb8205351eefa0b5be078149f8f5f277a99dda0601bc8d8647a56cd",
      "3546b5d371127f6cb30c4df4b596bbfba0ab6f62bfb9294f6a533f9e119e0661",
      "8c38eb244937e9bb057ac6372d343111a73bb264e94484d899059bdaef234a10"
    ]

    n =
      Enum.map(devices, fn d ->
        %Pigeon.APNS.Notification{
          device_token: d,
          payload: %{
            "aps" => %{
              "alert" => %{"title" => "Rail invited you for a call"}
            },
            "type" => "invite",
            "user_id" => "0000017b-86b5-039d-0242-ac1100020000"
          },
          push_type: "alert",
          topic: "since.app.ios"
        }
      end)

    Pigeon.APNS.push(n, to: :dev)

    # T.PushNotifications.APNSJob.perform(%Oban.Job{args: args})
  end

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
