defmodule Mix.Tasks.Events do
  @moduledoc "Mix tasks to download events stored in CSV on S3 into SQLite DB for data science and stuff"
  use Mix.Task

  defmodule Repo do
    use Ecto.Repo, adapter: Ecto.Adapters.SQLite3, otp_app: :t
  end

  @shortdoc "Simply calls the Hello.say/0 function."
  def run(opts) do
    database = opt(opts, "-o") || "events.sqlite3"
    Logger.configure(level: :warn)

    region = opt(opts, "--region") || "eu-north-1"
    bucket = opt(opts, "--bucket") || System.fetch_env!("AWS_S3_BUCKET_EVENTS")

    {:ok, _} = Finch.start_link(name: T.Finch)

    {:ok, _} = Application.ensure_all_started(:ecto_sqlite3)
    {:ok, _} = Repo.start_link(database: database)

    Repo.query!(
      "create table if not exists likes (id uuid primary key, by_user_id uuid, user_id uuid)"
    )

    Repo.query!(
      "create table if not exists seen (id uuid primary key, by_user_id uuid, type, resource_id uuid, json_timings json)"
    )

    Repo.query!(
      "create table if not exists contact_clicks (id uuid primary key, by_user_id uuid, user_id uuid, contact json)"
    )

    {:ok, task_sup} = Task.Supervisor.start_link()

    bucket
    |> ExAws.S3.list_objects_v2(prefix: "like")
    |> ExAws.stream!(region: region)
    |> async_stream(task_sup, fn %{key: key} ->
      IO.puts("Downloading #{key}")
      %{body: body} = bucket |> ExAws.S3.get_object(key) |> ExAws.request!(region: region)

      to_insert =
        body
        |> NimbleCSV.RFC4180.parse_string(skip_headers: false)
        |> Enum.map(fn [event_id, by_user_id, user_id] ->
          %{id: event_id, by_user_id: by_user_id, user_id: user_id}
        end)

      Repo.insert_all("likes", to_insert, on_conflict: :nothing, conflict_target: [:id])
    end)
    |> Stream.run()

    bucket
    |> ExAws.S3.list_objects_v2(prefix: "seen")
    |> ExAws.stream!(region: region)
    |> async_stream(task_sup, fn %{key: key} ->
      IO.puts("Downloading #{key}")
      %{body: body} = bucket |> ExAws.S3.get_object(key) |> ExAws.request!(region: region)

      body
      |> NimbleCSV.RFC4180.parse_string(skip_headers: false)
      |> Enum.chunk_every(1000)
      |> Enum.each(fn chunk ->
        to_insert =
          Enum.map(chunk, fn
            [event_id, by_user_id, type, resource_id, json_timings] ->
              %{
                id: event_id,
                by_user_id: by_user_id,
                type: type,
                resource_id: resource_id,
                json_timings: json_timings
              }

            # old format, before https://github.com/getsince/test3/commit/1930c94fa63a493a37031b59a2818f80f7cfabaa
            [event_id, by_user_id, resource_id, json_timings] ->
              %{
                id: event_id,
                by_user_id: by_user_id,
                type: "feed",
                resource_id: resource_id,
                json_timings: json_timings
              }
          end)

        Repo.insert_all("seen", to_insert, on_conflict: :nothing, conflict_target: [:id])
      end)
    end)
    |> Stream.run()

    bucket
    |> ExAws.S3.list_objects_v2(prefix: "contact")
    |> ExAws.stream!(region: region)
    |> async_stream(task_sup, fn %{key: key} ->
      IO.puts("Downloading #{key}")
      %{body: body} = bucket |> ExAws.S3.get_object(key) |> ExAws.request!(region: region)

      body
      |> NimbleCSV.RFC4180.parse_string(skip_headers: false)
      |> Enum.chunk_every(1000)
      |> Enum.each(fn chunk ->
        to_insert =
          Enum.map(chunk, fn
            [event_id, by_user_id, user_id, contact] ->
              %{
                id: event_id,
                by_user_id: by_user_id,
                user_id: user_id,
                contact: contact
              }
          end)

        Repo.insert_all("contact_clicks", to_insert, on_conflict: :nothing, conflict_target: [:id])
      end)
    end)
    |> Stream.run()

    Repo.query!("pragma wal_checkpoint(truncate)")
  end

  defp async_stream(enum, task_sup, fun) do
    Task.Supervisor.async_stream_nolink(task_sup, enum, fun,
      ordered: false,
      max_concurrency: 100,
      timeout: 30000
    )
  end

  defp opt(opts, key) do
    if idx = Enum.find_index(opts, fn v -> v == key end) do
      Enum.at(opts, idx + 1)
    end
  end
end
