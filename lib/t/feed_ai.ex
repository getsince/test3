# defmodule T.FeedAI do
#   @moduledoc false
#   alias T.{Repo, Workflows}
#   import T.Cluster, only: [primary_rpc: 3]

#   @doc """
#   Starts FeedAI workflow on a primary node unless it has
#   already been started within the last 30 minutes
#   """
#   def maybe_start_workflow do
#     primary_rpc(__MODULE__, :local_maybe_start_workflow, [])
#   end

#   @doc """
#   Starts FeedAI workflow on a primary node
#   """
#   def start_workflow do
#     primary_rpc(__MODULE__, :local_start_workflow, [])
#   end

#   def instance_name do
#     :t
#     |> Application.fetch_env!(__MODULE__)
#     |> Keyword.fetch!(:instance_name)
#   end

#   @doc false
#   def local_maybe_start_workflow do
#     instances = list_ec2([{"tag:Name", instance_name()}])
#     thirty_min_ago = DateTime.add(DateTime.utc_now(), -30 * 60)

#     has_been_run_within_thirty_min? =
#       Enum.any?(instances, fn %{launch_time: launch_time} ->
#         DateTime.compare(thirty_min_ago, launch_time) in [:gt, :eq]
#       end)

#     unless has_been_run_within_thirty_min? do
#       local_start_workflow()
#     end
#   end

#   @doc false
#   def local_start_workflow do
#     instance_name = instance_name()

#     Workflows.start_workflow(
#       inputs: [
#         up: fn _changes -> generate_inputs() end,
#         down: fn %{inputs: inputs} -> cleanup_inputs(inputs) end
#       ],
#       ec2: [
#         up: fn _changes -> launch_ec2(instance_name) end,
#         down: fn %{ec2: ec2} -> terminate_ec2(ec2.id) end
#       ],
#       ssh: [
#         up: fn %{ec2: ec2} -> ssh_into_retry(ec2) end,
#         # default is 5
#         attempts: 10
#       ],
#       # TODO what if ssh connection fails in the steps below?
#       upload_inputs: [
#         up: fn %{ssh: ssh, inputs: inputs} -> upload_inputs(ssh, inputs) end
#       ],
#       run_script: [
#         up: fn %{ssh: ssh} -> run_script(ssh) end
#       ],
#       output: [
#         up: fn %{ssh: ssh} -> download_output(ssh) end,
#         down: fn %{output: output} -> File.rm!(output) end
#       ],
#       load_output: [
#         up: fn %{output: calculated_feed} -> load_calculated_feed(calculated_feed) end
#       ]
#     )
#   end

#   @doc """
#   Finds ec2 instances that were created for feed ai but don't have a workflow running for them
#   """
#   @spec find_stray_instances :: [instance_id :: String.t()]
#   def find_stray_instances do
#     filters = [
#       {"tag:Name", [instance_name()]},
#       {"instance-state-name", ["running"]}
#     ]

#     instances = Enum.map(list_ec2(filters), & &1.id)

#     running =
#       Enum.flat_map(Workflows.primary_list_running(), fn {_node, workflows} ->
#         Enum.flat_map(workflows, fn {_id, %{changes: changes}} ->
#           case changes do
#             %{ec2: %{id: id}} -> [id]
#             _other -> []
#           end
#         end)
#       end)

#     instances -- running
#   end

#   @doc """
#   Terminates instances returned from `find_stray_instances/0`
#   """
#   def prune_stray_instances do
#     instances = find_stray_instances()
#     Enum.each(instances, &terminate_ec2/1)
#   end

#   @doc false
#   def generate_inputs do
#     %{
#       profiles: dump_to_csv("profiles"),
#       gender_preferences: dump_to_csv("gender_preferences"),
#       seen_profiles: dump_to_csv("seen_profiles"),
#       seen: restore_seen()
#     }
#   end

#   @doc false
#   def cleanup_inputs(inputs) do
#     for {_, v} <- inputs, do: File.rm!(v)
#   end

#   defp dump_to_csv(table) do
#     tmp = System.tmp_dir!()
#     rand = :rand.uniform(10_000_000)
#     csv = table <> "-#{rand}.csv"
#     part = csv <> ".part"

#     csv_path = Path.join(tmp, csv)
#     part_path = Path.join(tmp, part)

#     File.touch!(part_path)
#     fd = File.open!(part_path, [:raw, :binary, :append])

#     query = "copy (select * from #{table}) to stdout with csv delimiter ',' header"

#     Repo.transaction(fn ->
#       Ecto.Adapters.SQL.stream(Repo, query, [], max_rows: 500)
#       |> Stream.each(fn %{rows: rows} -> :ok = :file.write(fd, rows) end)
#       |> Stream.run()
#     end)

#     File.close(fd)
#     File.rename!(part_path, csv_path)

#     csv_path
#   end

#   defp restore_seen do
#     client = T.AWS.client()
#     bucket = System.fetch_env!("AWS_S3_BUCKET_EVENTS")

#     table = "seen"

#     tmp = System.tmp_dir!()
#     rand = :rand.uniform(10_000_000)
#     csv = table <> "-#{rand}.csv"
#     part = csv <> ".part"

#     csv_path = Path.join(tmp, csv)
#     part_path = Path.join(tmp, part)

#     File.touch!(part_path)
#     fd = File.open!(part_path, [:binary, :append])

#     s3_list_objects_stream(client, bucket, _prefix = "seen")
#     |> async_stream(fn %{"Key" => key} ->
#       :erlang.garbage_collect(self())

#       typed_rows =
#         s3_get_object_body(client, bucket, key)
#         |> NimbleCSV.RFC4180.parse_string(skip_headers: false)
#         |> Enum.map(fn
#           [_event_id, _by_user_id, _type, _resource_id, _json_timings] = ready ->
#             ready

#           # old format, before https://github.com/getsince/test3/commit/1930c94fa63a493a37031b59a2818f80f7cfabaa
#           [event_id, by_user_id, resource_id, json_timings] ->
#             [event_id, by_user_id, "feed", resource_id, json_timings]
#         end)

#       data =
#         NimbleCSV.RFC4180.dump_to_iodata([
#           ["event_id", "by_user_id", "type", "resource_id", "json_timings"] | typed_rows
#         ])

#       :ok = IO.binwrite(fd, data)
#     end)
#     |> Stream.run()

#     File.close(fd)
#     File.rename!(part_path, csv_path)

#     csv_path
#   end

#   @task_sup T.TaskSupervisor

#   defp async_stream(enum, fun) do
#     Task.Supervisor.async_stream_nolink(@task_sup, enum, fun,
#       ordered: false,
#       max_concurrency: 100,
#       timeout: 30000
#     )
#   end

#   @doc false
#   def launch_ec2(instance_name) do
#     {:ok, %{"id" => id, "private_ip" => private_ip}, %{status_code: 200}} =
#       AWS.EC2.run_instances(client, %{
#         "ami" => "ami-0908019583c0003da",
#         "min_count" => 1,
#         "max_count" => 1,
#         "instance_type" => "c5.large",
#         "key_name" => "feed",
#         "tag_specifications" => %{"instance" => %{"Name" => instance_name}},
#         "subnet_id" =>
#           Enum.random([
#             # 10.0.101.0/24
#             "subnet-00b6bd7aaf9b4d14b",
#             # 10.0.102.0/24
#             "subnet-09e72f08e1b8226f3",
#             # 10.0.103.0/24
#             "subnet-0e85ab49a9d0d8fed"
#           ])
#       })

#     %{id: id, private_ip: private_ip}
#   end

#   @doc false
#   def ssh_into_retry(%{private_ip: ip} = ec2) do
#     Logger.metadata(feed_ai_ec2_ip: ip)

#     case SSHKit.SSH.connect(ip, user: "ec2-user", key_cb: __MODULE__.SSH) do
#       {:ok, conn} -> conn
#       {:error, :etimedout} -> ssh_into_retry(ec2)
#     end
#   end

#   defmodule SSH do
#     @moduledoc false
#     @behaviour :ssh_client_key_api

#     @impl true
#     def is_host_key(_key, _hostname, _alg, _opts), do: true

#     @impl true
#     def user_key(:"ssh-rsa", _opts) do
#       # https://eu-north-1.console.aws.amazon.com/ec2/v2/home?region=eu-north-1#KeyPairs:v=3;search=:feed
#       pkey_data = System.fetch_env!("FEED_KEY")
#       [pem_entry] = :public_key.pem_decode(pkey_data)
#       {:ok, :public_key.pem_entry_decode(pem_entry)}
#     end
#   end

#   @doc false
#   def upload_inputs(ssh, inputs) do
#     :ok = SSHKit.SCP.upload(ssh, inputs.profiles, "~/profiles.csv")
#     :ok = SSHKit.SCP.upload(ssh, inputs.gender_preferences, "~/gender_preferences.csv")
#     :ok = SSHKit.SCP.upload(ssh, inputs.seen_profiles, "~/seen_profiles.csv")
#     :ok = SSHKit.SCP.upload(ssh, inputs.seen, "~/seen.csv")
#   end

#   @doc false
#   def run_script(ssh, gist_url \\ System.fetch_env!("ALGO_GIST_URL")) do
#     script = gist_url |> String.split("/") |> List.last()
#     {:ok, _, 0} = SSHKit.SSH.run(ssh, "curl -LO #{gist_url}")
#     {:ok, _, 0} = SSHKit.SSH.run(ssh, "conda activate pytorch_p39 && python3 #{script}")
#   end

#   @doc false
#   def download_output(ssh) do
#     calculated_feed = Path.join(System.tmp_dir!(), "calculated_feed-#{:rand.uniform(10000)}.csv")
#     :ok = SSHKit.SCP.download(ssh, "~/calculated_feed.csv", calculated_feed)
#     calculated_feed
#   end

#   @doc false
#   def terminate_ec2(instance_id) do
#     {:ok, _, %{status_code: 200}} =
#       AWS.EC2.terminate_instances(T.AWS.client(), %{"instance_id" => instance_id})
#   end

#   @doc false
#   def load_calculated_feed(path) do
#     {:ok, :ok} =
#       Repo.transaction(fn ->
#         Repo.query!("truncate calculated_feed")

#         path
#         |> File.stream!()
#         |> NimbleCSV.RFC4180.parse_stream(skip_headers: true)
#         |> Stream.chunk_every(2000)
#         |> Stream.each(fn chunk ->
#           rows =
#             Enum.map(chunk, fn [for_user_id, user_id, score] ->
#               [
#                 for_user_id: Ecto.UUID.dump!(for_user_id),
#                 user_id: Ecto.UUID.dump!(user_id),
#                 score: String.to_float(score)
#               ]
#             end)

#           Repo.insert_all("calculated_feed", rows)
#         end)
#         |> Stream.run()
#       end)
#   end

#   @doc false
#   def list_ec2(filters) do
#     request = ExAws.EC2.describe_instances(filters: filters)
#     # {:ok, %{body: body}} = ExAws.request(request, region: @region)

#     # SweetXml.parse(body)
#     # # |> SweetXml.xpath(~x"//DescribeInstancesResponse/reservationSet/item/instancesSet/item"l)
#     # |> Enum.map(fn xml ->
#     #   # launch_time = SweetXml.xpath(xml, ~x"launchTime/text()"s)
#     #   launch_time = nil
#     #   {:ok, launch_time, 0} = DateTime.from_iso8601(launch_time)

#     #   %{
#     #     id: SweetXml.xpath(xml, ~x"instanceId/text()"s),
#     #     private_ip: SweetXml.xpath(xml, ~x"privateIpAddress/text()"s),
#     #     launch_time: launch_time
#     #   }
#     # end)
#     []
#   end

#   def s3_list_objects_stream(client, bucket, prefix) do
#     Stream.resource(
#       fn -> _continuation_token = nil end,
#       fn
#         :halt ->
#           {:halt, _token = nil}

#         continuation_token ->
#           result =
#             AWS.S3.list_objects_v2(
#               client,
#               bucket,
#               continuation_token,
#               _delimeter = nil,
#               _encoding_type = nil,
#               _fetch_owner = nil,
#               _max_keys = nil,
#               prefix
#             )

#           case result do
#             {:ok, %{"ListBucketResult" => result}, _} ->
#               case result do
#                 %{
#                   "Contents" => contents,
#                   "IsTruncated" => "true",
#                   "NextContinuationToken" => token
#                 } ->
#                   {contents, token}

#                 %{"Contents" => contents, "IsTruncated" => "false"} ->
#                   {contents, :halt}

#                 %{"KeyCount" => "0"} ->
#                   {:halt, _token = nil}
#               end
#           end
#       end,
#       fn _continuation_token -> :ok end
#     )
#   end

#   def s3_get_object_body(client, bucket, key) do
#     {:ok, %{"Body" => body}, _} = AWS.S3.get_object(client, bucket, key)
#     body
#   end
# end
