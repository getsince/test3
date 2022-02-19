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
    # File.ls("*.csv") |> TODO
    {:ok, open_buffer(Map.new(opts))}
  end

  @impl true
  def handle_cast({:add, row}, %{fd: fd} = state) do
    :file.write(fd, row)
    {:noreply, state}
  end

  @impl true
  def handle_info(:upload, state) do
    state = close_buffer(state)
    upload(state)
    {:noreply, open_buffer(state)}
  end

  @buffer "buffer.csv"

  defp open_buffer(%{dir: dir} = state) do
    opts = [:raw, :append, {:delayed_write, 512_000, 10_000}]
    File.mkdir_p!(dir)
    fd = File.open!(dir_path(dir, @buffer), opts)

    # TODO upload when file size reaches some threshold like 100MB
    timer = Process.send_after(self(), :upload, :timer.hours(1))

    Map.merge(state, %{fd: fd, timer: timer})
  end

  defp upload(%{dir: dir}) do
    filename = "#{:rand.uniform(1000)}.csv"
    :ok = File.rename(dir_path(dir, @buffer), dir_path(dir, filename))
    async_upload(dir, filename)
  end

  defp dir_path(dir, file) when is_binary(dir) do
    Path.join(dir, file)
  end

  defp close_buffer(%{fd: fd, timer: timer} = state) do
    Process.cancel_timer(timer)

    case File.close(fd) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      _error -> :ok = File.close(fd)
    end

    Map.drop(state, [:fd, :timer])
  end

  defp async_upload(dir, filename) do
    Task.Supervisor.start_child(T.TaskSupervisor, fn ->
      bucket = Events.bucket()

      {y, mo, d} = :erlang.date()
      {h, m, s} = :erlang.time()
      s3_key = Path.join([dir, "#{y}/#{mo}/#{d}/#{h}/#{m}/#{s}", filename])

      dir_path(dir, filename)
      |> ExAws.S3.Upload.stream_file()
      |> ExAws.S3.upload(bucket, s3_key)
      |> ExAws.request!(region: "eu-north-1")

      File.rm(dir_path(dir, filename))
    end)
  end

  @impl true
  def terminate(_reason, state) do
    close_buffer(state)
    upload(state)
    {:ok, state}
  end
end
