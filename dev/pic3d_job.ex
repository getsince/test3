# import Config

# config :s, Oban,
#   repo: S.Repo,
#   plugins: [Oban.Plugins.Pruner],
#   queues: [pic3d: 2]

# config :ex_aws,
#   json_codec: Jason,
#   region: "eu-central-1"

# config :s, s3_bucket: System.fetch_env!("AWS_S3_BUCKET")

# config :s, S.Repo,
#   url: System.fetch_env!("DATABASE_URL"),
#   pool_size: String.to_integer(System.get_env("POOL_SIZE") || "20")

# if config_env() == :prod do
#   config :logger, level: :info

#   config :logger,
#     backends: [:console, Sentry.LoggerBackend]

#   config :sentry,
#     environment_name: config_env(),
#     included_environments: [:prod]

#   config :logger, Sentry.LoggerBackend,
#     level: :warn,
#     capture_log_messages: true

#   config :sentry,
#     dsn: System.fetch_env!("SENTRY_DSN")
# end

defmodule S.ObanErrorReporter do
  @moduledoc false

  def handle_event([:oban, :job, :exception], measure, meta, _) do
    extra =
      meta
      |> Map.take([:id, :args, :queue, :worker])
      |> Map.merge(measure)

    Sentry.capture_exception(meta.error, stacktrace: meta.stacktrace, extra: extra)
  end

  def handle_event([:oban, :circuit, :trip], _measure, meta, _) do
    Sentry.capture_exception(meta.error, stacktrace: meta.stacktrace, extra: meta)
  end
end

defmodule S.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      S.Repo,
      {Oban, oban_config()}
    ]

    :telemetry.attach_many(
      "oban-errors",
      [[:oban, :job, :exception], [:oban, :circuit, :trip]],
      &S.ObanErrorReporter.handle_event/4,
      %{}
    )

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: S.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp oban_config do
    Application.get_env(:s, Oban)
  end
end

defmodule S.Repo do
  use Ecto.Repo,
    otp_app: :s,
    adapter: Ecto.Adapters.Postgres
end

defmodule S do
  require Logger

  def bucket do
    Application.fetch_env!(:s, :s3_bucket)
  end

  def download_pic_data(s3_key) do
    Logger.info("downloading #{s3_key}")
    %{body: body, status_code: 200} = bucket() |> ExAws.S3.get_object(s3_key) |> ExAws.request!()

    body
  end

  def write_pic_data_to_tmp(s3_key, data) do
    File.mkdir_p(workdir(s3_key))
    path = Path.join([workdir(s3_key), ensure_ends_with_jpg(s3_key)])
    Logger.info("saving #{s3_key} to #{path}")
    File.write!(path, data)
    path
  end

  def delete_tmp(s3_key) do
    # File.rm!(workdir(s3_key))
    :os.cmd('sudo rm -rf #{workdir(s3_key)}')
  end

  defp workdir(s3_key) do
    Path.join([System.tmp_dir(), s3_key])
  end

  def ensure_ends_with_jpg(s3_key) do
    if String.ends_with?(s3_key, ".jpg") do
      s3_key
    else
      s3_key <> ".jpg"
    end
  end

  def images do
    File.ls("/home/ubuntu/3d-photo-inpainting/image")
  end

  def read_arguments do
    File.read!("/home/ubuntu/3d-photo-inpainting/argument.yml")
  end

  def create_arguments(s3_key) do
    Logger.info("creating args for #{s3_key}")
    args = read_arguments()
    workdir = workdir(s3_key)

    args =
      String.split(args, "\n")
      |> Enum.map(fn row ->
        if String.starts_with?(row, "src_folder:") do
          "src_folder: " <> workdir
        else
          row
        end
      end)
      |> Enum.join("\n")

    path = Path.join([workdir, "argument.yml"])
    File.write!(path, args)
    path
  end

  # port =
  #   Port.open({:spawn_executable, }, [
  #     :stderr_to_stdout,
  #     :binary,
  #     :exit_status,
  #     args:
  #   ])

  # receive do
  #   {^port, {:data, data}} ->
  #     IO.puts(data)

  #   {^port, {:exit_status, 0}} ->
  #     IO.puts("Command success")

  #   {^port, {:exit_status, status}} ->
  #     IO.puts("Command error, status #{status}")
  # end

  def run do
    run("ef954f6d-23ee-4be1-8aab-d9aeae24c9fc")
  end

  def run(s3_key) do
    pic_data = download_pic_data(s3_key)
    write_pic_data_to_tmp(s3_key, pic_data)
    args_path = create_arguments(s3_key)
    video_path = create_3d_vid(args_path)
    upload_video(s3_key, video_path)
    frame_path = extract_first_frame(s3_key, video_path)
    upload_thumbnail(s3_key, frame_path)

    # delete_tmp(s3_key)
    delete_mesh(s3_key)
    delete_depth(s3_key)
    delete_video(s3_key)

    :ok
  end

  def create_3d_vid(args_path) do
    Logger.info("creating 3d vid for #{args_path}")
    # TODO copy bin/run.sh into release
    # https://hexdocs.pm/elixir/Port.html#module-zombie-operating-system-processes, doesn't work though

    root_path = System.get_env("RELEASE_ROOT") || File.cwd!() <> "/rel/overlays/"
    wrapper_sh = Path.join([root_path, "wrapper.sh"])
    run_sh = Path.join([root_path, "run.sh"])
    {o, 0} = System.cmd(wrapper_sh, [run_sh, args_path])
    video_path = String.trim(o) |> String.split() |> List.last()
    String.ends_with?(video_path, ".mp4") || raise "unexpected video path #{video_path}"
    Path.join(["/home/ubuntu/3d-photo-inpainting/", video_path])
  end

  def delete_mesh(s3_key) do
    File.ls!("/home/ubuntu/3d-photo-inpainting/mesh")
    |> Enum.filter(fn f -> String.contains?(f, key_no_ext(s3_key)) end)
    |> Enum.each(fn f -> File.rm!(Path.join(["/home/ubuntu/3d-photo-inpainting/mesh", f])) end)
  end

  defp delete_depth(s3_key) do
    File.ls!("/home/ubuntu/3d-photo-inpainting/depth")
    |> Enum.filter(fn f -> String.contains?(f, key_no_ext(s3_key)) end)
    |> Enum.each(fn f -> File.rm!(Path.join(["/home/ubuntu/3d-photo-inpainting/depth", f])) end)
  end

  def upload_video(s3_key, video_path) do
    key = s3_key <> ".mp4"
    Logger.info("uploading video for #{key} from #{video_path}")
    body = File.read!(video_path)

    %{status_code: 200} =
      ExAws.S3.put_object(bucket(), key, body, acl: :public_read) |> ExAws.request!()
  end

  defp delete_video(s3_key) do
    File.ls!("/home/ubuntu/3d-photo-inpainting/video")
    |> Enum.filter(fn f -> String.contains?(f, key_no_ext(s3_key)) end)
    |> Enum.each(fn f -> File.rm!(Path.join(["/home/ubuntu/3d-photo-inpainting/video", f])) end)
  end

  defp key_no_ext(s3_key) do
    String.replace_trailing(s3_key, ".jpg", "")
  end

  def extract_first_frame(s3_key, video_path) do
    Logger.info("extracting thumbnail for #{video_path}")
    frame_path = Path.join([System.tmp_dir!(), s3_key, "thumbnail.jpeg"])
    {"", 0} = System.cmd("ffmpeg", ["-i", video_path, "-vframes", "1", frame_path, "-y"])
    frame_path
  end

  def upload_thumbnail(s3_key, path) do
    key = s3_key <> ".jpeg"
    Logger.info("uploading thumbnail #{key} from #{path}")
    body = File.read!(path)

    %{status_code: 200} =
      ExAws.S3.put_object(bucket(), key, body, acl: :public_read)
      |> ExAws.request!()
  end
end

defmodule S.Pic3dJob do
  use Oban.Worker, queue: :pic3d

  @impl true
  def perform(%Oban.Job{args: args}) do
    %{"s3_key" => s3_key} = args
    S.run(s3_key)
  end

  # TODO on job fail, stop the python process
  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(15)
end
