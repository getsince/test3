defmodule Dev do
  def user_keys do
    Finch.start_link(name: T.Finch)

    client = T.AWS.client()

    s3_list_objects_stream(client, "since-when-are-you-happy")
    |> Stream.map(fn object ->
      %{"Key" => key, "LastModified" => last_modified} = object
      [key, last_modified]
    end)
    |> NimbleCSV.RFC4180.dump_to_stream()
    |> Stream.into(File.stream!("s3.csv", [:write, :utf8]))
    |> Stream.run()
  end

  def s3_list_objects_stream(client, bucket) do
    Stream.resource(
      fn -> _continuation_token = nil end,
      fn
        :halt ->
          {:halt, _token = nil}

        continuation_token ->
          result =
            AWS.S3.list_objects_v2(client, bucket, continuation_token)

          case result do
            {:ok, %{"ListBucketResult" => result}, _} ->
              case result do
                %{
                  "Contents" => contents,
                  "IsTruncated" => "true",
                  "NextContinuationToken" => token
                } ->
                  {contents, token}

                %{"Contents" => contents, "IsTruncated" => "false"} ->
                  {contents, :halt}

                %{"KeyCount" => "0"} ->
                  {:halt, _token = nil}
              end
          end
      end,
      fn _continuation_token -> :ok end
    )
  end

  def to_delete do
    csv_to_set = fn file ->
      File.stream!(file)
      |> NimbleCSV.RFC4180.parse_stream(skip_headers: true)
      |> Stream.map(fn [key] -> key end)
      |> MapSet.new()
    end

    month_ago = Date.add(Date.utc_today(), -30)

    more_than_month_old? = fn last_modified ->
      {:ok, last_modified, 0} = DateTime.from_iso8601(last_modified)
      Date.compare(last_modified, month_ago) == :lt
    end

    used_keys =
      csv_to_set.("profiles.csv")
      |> MapSet.union(csv_to_set.("chat_messages.csv"))
      |> MapSet.union(csv_to_set.("match_interations.csv"))

    File.stream!("s3.csv")
    |> NimbleCSV.RFC4180.parse_stream(skip_headers: true)
    |> Enum.reject(fn [key, last_modified] ->
      MapSet.member?(used_keys, key) and more_than_month_old?.(last_modified)
    end)
  end

  def delete_s3(keys) do
    Finch.start_link(name: T.Finch)
    client = T.AWS.client()

    keys
    |> Enum.chunk_every(1000)
    |> Enum.map(fn keys ->
      AWS.S3.delete_objects(
        client,
        "since-when-are-you-happy",
        %{"Delete" => %{"Object" => Enum.map(keys, fn key -> %{"Key" => key} end)}}
      )
    end)
  end

  def force_app_upgrade() do
    alert1_ru = %{
      "aps" => %{
        "alert" => %{
          "title" => "Ура, обновление! 🔥",
          "body" => "Новый режим — голосовая почта 🎤"
        }
      }
    }

    alert1_en = %{
      "aps" => %{
        "alert" => %{
          "title" => "Hurray, this is an update! 🔥",
          "body" => "Meet new mode: voicemail 🎤"
        }
      }
    }

    apns = T.Accounts.APNSDevice |> T.Repo.all()

    devices =
      Enum.map(apns, fn %{device_id: id} = device -> %{device | device_id: Base.encode16(id)} end)

    for device <- devices do
      %T.Accounts.APNSDevice{device_id: device_id, locale: locale, topic: topic, env: env} =
        device

      env =
        case env do
          "prod" -> :prod
          "sandbox" -> :dev
          nil -> :dev
        end

      case locale do
        "ru" ->
          APNS.build_notification(device_id, topic, alert1_ru, env) |> APNS.push(T.Finch)

        "en" ->
          APNS.build_notification(device_id, topic, alert1_en, env) |> APNS.push(T.Finch)

        _ ->
          APNS.build_notification(device_id, topic, alert1_ru, env) |> APNS.push(T.Finch)
      end
    end
  end

  def wait(_changes) do
    receive do
      :never -> :ok
    end
  end

  alias T.Workflows

  def run_workflow do
    Workflows.start_workflow(
      a: [
        up: {__MODULE__, :wait, []}
      ]
    )
  end
end
