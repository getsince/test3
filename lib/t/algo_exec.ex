defmodule T.AlgoExec do
  @moduledoc "Runs feed algo script on remote ec2 instance"
  use GenServer
  import T.Cluster, only: [primary_rpc: 3, list_primary_nodes: 0]
  alias T.Repo
  @task_sup T.TaskSupervisor

  def start_link(opts) do
    id = opts[:id] || Ecto.Bigflake.UUID.generate()
    opts = Keyword.put_new(opts, :id, id)
    GenServer.start_link(__MODULE__, opts, name: via(id))
  end

  defp via(id) do
    {:via, Registry, {__MODULE__.Registry, id}}
  end

  @doc """
  Lists currently running processes
  """
  @spec list_running :: [integer]
  def list_running do
    list_primary_nodes()
    |> :erpc.multicall(__MODULE__, :local_list_running, [])
    |> Enum.flat_map(fn {:ok, running} -> running end)
  end

  @spec list_running :: [integer]
  def local_list_running do
    Registry.select(__MODULE__.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  # TODO + monitor
  def attach(id), do: GenServer.call(via(id), :attach)
  def detach(id), do: GenServer.call(via(id), :detach)

  @doc "Launches the process on a primary instance"
  def run(opts \\ []) do
    primary_rpc(__MODULE__, :local_run, [opts])
  end

  @doc false
  def local_run(opts) do
    DynamicSupervisor.start_child(__MODULE__.Supervisor, {__MODULE__, opts})
  end

  @impl true
  def init(opts) do
    state = %{
      id: Keyword.fetch!(opts, :id),
      # TODO tasks or steps
      task: :generate_inputs,
      # TODO log (time + level + message)
      lv: opts[:subscribe],
      inputs: nil,
      ec2: nil
    }

    task(fn -> generate_inputs(state) end)
    {:ok, state}
  end

  defp task(fun) do
    Task.Supervisor.async_nolink(@task_sup, fun)
  end

  defp log(%{lv: lv} = _state, message) do
    if lv, do: send(lv, {__MODULE__, :message, message})
  end

  @impl true
  def handle_info({ref, state}, _old_state) do
    Process.demonitor(ref, [:flush])

    if task = state.task do
      task(fn -> apply(__MODULE__, task, [state]) end)
      {:noreply, state}
    else
      {:stop, :normal, state}
    end
  end

  def handle_info({:DOWN, _ref, :process, _, reason}, state) do
    # TODO format
    log(state, inspect(reason))
    task(fn -> apply(__MODULE__, state.task, [state]) end)
    {:noreply, state}
  end

  @doc false
  def generate_inputs(state) do
    log(state, "generating inputs...")

    log(state, "dumping profiles table to csv...")
    profiles = dump_to_csv("profiles")
    log(state, "dumped profiles table to #{profiles}")

    log(state, "dumping seen_profiles table to csv...")
    seen_profiles = dump_to_csv("seen_profiles")
    log(state, "dumped seen_profiles table to #{seen_profiles}")

    log(state, "downloading seen csvs from s3 and mashing them together...")
    seen = restore_seen()
    log(state, "dumped seen to #{seen}")

    inputs = %{
      profiles: profiles,
      seen_profiles: seen_profiles,
      seen: seen
    }

    log(state, "generated inputs")
    %{state | task: :launch_ec2, inputs: inputs}
  end

  def launch_ec2(state) do
    opts = [ami: "ami-0908019583c0003da", instance_type: "c5.large", key_name: "feed"]
    log(state, "launching ec2 instance opts=#{inspect(opts)}...")
    {ami, opts} = Keyword.pop!(opts, :ami)

    opts =
      Keyword.merge(opts,
        tag_specifications: [instance: [{"Name", "feed-vm"}]],
        # https://eu-north-1.console.aws.amazon.com/vpc/home?region=eu-north-1#subnets:search=since-backend
        subnet_id:
          Enum.random([
            # 10.0.101.0/24
            "subnet-00b6bd7aaf9b4d14b",
            # 10.0.102.0/24
            "subnet-09e72f08e1b8226f3",
            # 10.0.103.0/24
            "subnet-0e85ab49a9d0d8fed"
          ])
      )

    %{status_code: 200, body: body} =
      ExAws.EC2.run_instances(ami, _min_count = 1, _max_count = 1, opts)
      |> ExAws.request!(region: "eu-north-1")

    ec2 = ec2_info(body)
    log(state, "launched ec2 instance #{inspect(ec2)}")
    %{state | task: :run_script, ec2: ec2}
  end

  @doc false
  def run_script(state) do
    %{inputs: inputs} = state
    ssh = ssh_into_retry(state)
    log(state, "connected to ec2 instance")

    log(state, "uploading profiles.csv to ec2 instance ...")
    :ok = SSHKit.SCP.upload(ssh, inputs.profiles, "~/profiles.csv")
    log(state, "uploading seen_profiles.csv to ec2 instance ...")
    :ok = SSHKit.SCP.upload(ssh, inputs.seen_profiles, "~/seen_profiles.csv")
    log(state, "uploading seen.csv to ec2 instance ...")
    :ok = SSHKit.SCP.upload(ssh, inputs.seen, "~/seen.csv")
    log(state, "uploaded inputs to ec2 instance")

    gist_url = System.fetch_env!("ALGO_GIST_URL")
    script = gist_url |> String.split("/") |> List.last()
    log(state, "downloading #{script} from #{gist_url}...")
    {:ok, _, 0} = SSHKit.SSH.run(ssh, "curl -LO #{gist_url}")
    log(state, "running #{script}...")
    {:ok, _, 0} = SSHKit.SSH.run(ssh, "conda activate pytorch_p39 && python3 #{script}")

    # fun: fn message, acc ->
    #   send(me, message)
    #   {:cont, acc}
    # end

    # * `{:data, channel, type, data}`
    # * `{:eof, channel}`
    # * `{:exit_signal, channel, signal, msg, lang}`
    # * `{:exit_status, channel, status}`
    # * `{:closed, channel}`

    log(state, "ran #{script}")

    log(state, "downloading calculated_feed.csv...")

    calculated_feed = Path.join(System.tmp_dir!(), "calculated_feed-#{:rand.uniform(10000)}.csv")

    :ok = SSHKit.SCP.download(ssh, "~/calculated_feed.csv", calculated_feed)
    log(state, "downloaded calculated_feed.csv to #{calculated_feed}")

    load_calculated_feed(calculated_feed)
    File.rm!(calculated_feed)

    %{state | task: :terminate_ec2}
  end

  @doc false
  def terminate_ec2(%{ec2: ec2} = state) do
    %{status_code: 200} =
      ExAws.EC2.terminate_instances([ec2.id])
      |> ExAws.request!(region: "eu-north-1")

    %{state | task: :cleanup_inputs}
  end

  @doc false
  def load_calculated_feed(path) do
    Repo.transaction(fn ->
      Repo.query!("truncate calculated_feed")

      Repo.query!(
        "copy calculated_feed (for_user_id, user_id, score) from '#{path}' delimiter ',' csv header;"
      )
    end)
  end

  @doc false
  def cleanup_inputs(%{inputs: inputs} = state) do
    for {_, v} <- inputs, do: File.rm!(v)
    %{state | task: nil}
  end

  defp dump_to_csv(table) do
    tmp = System.tmp_dir!()
    rand = :rand.uniform(10_000_000)
    csv = table <> "-#{rand}.csv"
    part = csv <> ".part"

    csv_path = Path.join(tmp, csv)
    part_path = Path.join(tmp, part)

    File.touch!(part_path)
    fd = File.open!(part_path, [:raw, :binary, :append])

    query = "copy (select * from #{table}) to stdout with csv delimiter ',' header"

    Repo.transaction(fn ->
      Ecto.Adapters.SQL.stream(Repo, query, [], max_rows: 500)
      |> Stream.each(fn %{rows: rows} -> :ok = :file.write(fd, rows) end)
      |> Stream.run()
    end)

    File.close(fd)
    File.rename!(part_path, csv_path)

    csv_path
  end

  defp restore_seen do
    bucket = System.fetch_env!("AWS_S3_BUCKET_EVENTS")
    region = "eu-north-1"

    table = "seen"

    tmp = System.tmp_dir!()
    rand = :rand.uniform(10_000_000)
    csv = table <> "-#{rand}.csv"
    part = csv <> ".part"

    csv_path = Path.join(tmp, csv)
    part_path = Path.join(tmp, part)

    File.touch!(part_path)
    fd = File.open!(part_path, [:binary, :append])

    bucket
    |> ExAws.S3.list_objects_v2(prefix: "seen")
    |> ExAws.stream!(region: region)
    |> async_stream(fn %{key: key} ->
      :erlang.garbage_collect(self())
      %{body: body} = bucket |> ExAws.S3.get_object(key) |> ExAws.request!()

      typed_rows =
        body
        |> NimbleCSV.RFC4180.parse_string(skip_headers: false)
        |> Enum.map(fn
          [_event_id, _by_user_id, _type, _resource_id, _json_timings] = ready ->
            ready

          # old format, before https://github.com/getsince/test3/commit/1930c94fa63a493a37031b59a2818f80f7cfabaa
          [event_id, by_user_id, resource_id, json_timings] ->
            [event_id, by_user_id, "feed", resource_id, json_timings]
        end)

      data =
        NimbleCSV.RFC4180.dump_to_iodata([
          ["event_id", "by_user_id", "type", "resource_id", "json_timings"] | typed_rows
        ])

      :ok = IO.binwrite(fd, data)
    end)
    |> Stream.run()

    File.close(fd)
    File.rename!(part_path, csv_path)

    csv_path
  end

  defp async_stream(enum, fun) do
    Task.Supervisor.async_stream_nolink(@task_sup, enum, fun,
      ordered: false,
      max_concurrency: 100,
      timeout: 30000
    )
  end

  defp ec2_info(xml) do
    import SweetXml, only: [sigil_x: 2]
    xml = SweetXml.parse(xml)

    %{
      id: SweetXml.xpath(xml, ~x"//RunInstancesResponse/instancesSet/item/instanceId/text()"s),
      private_ip:
        SweetXml.xpath(xml, ~x"//RunInstancesResponse/instancesSet/item/privateIpAddress/text()"s)
    }
  end

  @doc false
  def ssh_into_retry(%{ec2: %{private_ip: ip}} = state) do
    log(state, "connecting to ec2 instance...")

    case SSHKit.SSH.connect(ip, user: "ec2-user", key_cb: __MODULE__.SSH) do
      {:ok, conn} -> conn
      {:error, :etimedout} -> ssh_into_retry(state)
    end
  end

  defmodule SSH do
    @moduledoc false
    @behaviour :ssh_client_key_api

    @impl true
    def is_host_key(_key, _hostname, _alg, _opts), do: true

    @impl true
    def user_key(:"ssh-rsa", _opts) do
      # https://eu-north-1.console.aws.amazon.com/ec2/v2/home?region=eu-north-1#KeyPairs:v=3;search=:feed
      pkey_data = System.fetch_env!("FEED_KEY")
      [pem_entry] = :public_key.pem_decode(pkey_data)
      {:ok, :public_key.pem_entry_decode(pem_entry)}
    end
  end
end
