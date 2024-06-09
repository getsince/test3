defmodule T.Events do
  use Supervisor
  alias __MODULE__.Buffer
  alias NimbleCSV.RFC4180, as: CSV

  @type uuid :: Ecto.Bigflake.UUID.t()

  def start_link(config) do
    Supervisor.start_link(__MODULE__, config, name: __MODULE__)
  end

  def bucket do
    :t |> Application.fetch_env!(__MODULE__) |> Keyword.fetch!(:bucket)
  end

  @impl true
  def init(config) do
    buffers = config[:buffers] || []

    children = [
      if :seen_buffer in buffers do
        Supervisor.child_spec({Buffer, dir: "seen", name: :seen_buffer}, id: :seen_buffer)
      end,
      if :like_buffer in buffers do
        Supervisor.child_spec({Buffer, dir: "like", name: :like_buffer}, id: :like_buffer)
      end
    ]

    children = Enum.reject(children, &is_nil/1)
    Supervisor.init(children, strategy: :one_for_one)
  end

  @spec save_seen_timings(:feed | :like | :match, uuid, uuid, list) :: :ok
  def save_seen_timings(type, by_user_id, resource_id, timings) do
    id = Ecto.Bigflake.UUID.generate()
    json_timings = :json.encode(timings)
    row = CSV.dump_to_iodata([[id, by_user_id, type, resource_id, json_timings]])
    GenServer.cast(:seen_buffer, {:add, row})
  end

  @spec save_like(uuid, uuid) :: :ok
  def save_like(by_user_id, user_id) do
    id = Ecto.Bigflake.UUID.generate()
    row = CSV.dump_to_iodata([[id, by_user_id, user_id]])
    GenServer.cast(:like_buffer, {:add, row})
  end
end
