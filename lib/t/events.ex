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
      if :seen_buffer in buffers do
        Supervisor.child_spec({Buffer, dir: "seen", name: :seen_buffer}, id: :seen_buffer)
      end,
      if :like_buffer in buffers do
        Supervisor.child_spec({Buffer, dir: "like", name: :like_buffer}, id: :like_buffer)
      end,
      if :contact_buffer in buffers do
        Supervisor.child_spec({Buffer, dir: "contact", name: :contact_buffer}, id: :contact_buffer)
      end
    ]

    children = Enum.reject(children, &is_nil/1)
    Supervisor.init(children, strategy: :one_for_one)
  end

  def save_seen_timings(type, by_user_id, user_id, timings) do
    id = Ecto.Bigflake.UUID.generate()
    row = CSV.dump_to_iodata([[id, by_user_id, type, user_id, Jason.encode_to_iodata!(timings)]])
    GenServer.cast(:seen_buffer, {:add, row})
  end

  def save_like(by_user_id, user_id) do
    id = Ecto.Bigflake.UUID.generate()
    row = CSV.dump_to_iodata([[id, by_user_id, user_id]])
    GenServer.cast(:like_buffer, {:add, row})
  end

  def save_contact_click(by_user_id, user_id, contact) do
    id = Ecto.Bigflake.UUID.generate()
    row = CSV.dump_to_iodata([[id, by_user_id, user_id, dump_contact(contact)]])
    GenServer.cast(:contact_buffer, {:add, row})
  end

  defp dump_contact(contact) when is_binary(contact), do: contact
  defp dump_contact(contact) when is_map(contact), do: Jason.encode_to_iodata!(contact)
end
