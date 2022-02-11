defmodule T.Events do
  use Supervisor
  alias __MODULE__.Buffer
  alias NimbleCSV.RFC4180, as: CSV

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
      if buffers[:seen_buffer] do
        Supervisor.child_spec({Buffer, dir: "seen", name: :seen_buffer}, id: :seen_buffer)
      end,
      if buffers[:like_buffer] do
        Supervisor.child_spec({Buffer, dir: "like", name: :like_buffer}, id: :like_buffer)
      end
    ]

    children = Enum.reject(children, &is_nil/1)
    Supervisor.init(children, strategy: :one_for_one)
  end

  def save_seen_timings(by_user_id, user_id, timings) do
    id = Ecto.Bigflake.UUID.generate()
    row = CSV.dump_to_iodata([[id, by_user_id, user_id, Jason.encode_to_iodata!(timings)]])
    GenServer.cast(:seen_buffer, {:add, row})
  end

  def save_like(by_user_id, user_id) do
    id = Ecto.Bigflake.UUID.generate()
    row = CSV.dump_to_iodata([[id, by_user_id, user_id]])
    GenServer.cast(:like_buffer, {:add, row})
  end
end
