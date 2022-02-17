defmodule T.Events.Buffer do
  @moduledoc false
  use GenServer
  alias T.Events

  def start_link(opts) do
    {opts, init_arg} = Keyword.split(opts, [:name])
    GenServer.start_link(__MODULE__, init_arg, opts)
  end

  @impl true
  def init(opts) do
    # TODO upload when file size reaches some threshold like 100MB
    Process.send_after(self(), :upload, :timer.hours(1))
    # File.ls("*.csv") |> TODO
    {:ok, open_buffer(Map.new(opts))}
  end

  @impl true
  def handle_cast({:add, row}, %{fd: fd} = state) do
    :file.write(fd, row)
    {:noreply, state}
  end

  @impl true
  def handle_info(:upload, %{fd: fd} = state) do
    close_buffer(fd)
    upload(state)
    {:noreply, open_buffer(state)}
  end

  @buffer "buffer.csv"

  defp open_buffer(%{dir: dir} = state) do
    opts = [:raw, :append, {:delayed_write, 512_000, 10_000}]
    File.mkdir_p!(dir)
    fd = File.open!(Path.join(dir, @buffer), opts)
    Map.put(state, :fd, fd)
  end

  defp upload(%{dir: dir}) do
    to_upload = Path.join(dir, "#{:rand.uniform(1000)}.csv")
    :ok = File.rename(@buffer, to_upload)
    async_upload(dir, to_upload)
  end

  defp close_buffer(%{fd: fd}) do
    case File.close(fd) do
      :ok -> :ok
      _error -> :ok = File.close(fd)
    end
  end

  defp async_upload(dir, filename) do
    Task.Supervisor.start_child(T.TaskSupervisor, fn ->
      bucket = Events.bucket()

      {y, mo, d} = :erlang.date()
      {h, m, s} = :erlang.time()
      s3_key = Path.join([dir, "#{y}/#{mo}/#{d}/#{h}/#{m}/#{s}", filename])

      filename
      |> ExAws.S3.Upload.stream_file()
      |> ExAws.S3.upload(bucket, s3_key)
      |> ExAws.request!(region: "eu-north-1")

      File.rm(filename)
    end)
  end

  @impl true
  def terminate(_reason, state) do
    close_buffer(state)
    upload(state)
    {:ok, state}
  end
end
