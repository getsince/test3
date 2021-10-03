defmodule Dev do
  # alias T.PushNotifications.APNS

  # click + -> can add session by picking user and inputting duration -> table updates
  # can select user to impersonate, if selected, can invite, call etc. based on status
  # search

  import Ecto.Query

  def bench(count, fun) when is_function(fun, 0) do
    {time, :ok} = :timer.tc(fn -> do_bench_exec(count, fun) end)
    format_time(time)
  end

  defp do_bench_exec(count, fun) when count > 0 do
    fun.()
    do_bench_exec(count - 1, fun)
  end

  defp do_bench_exec(0, _fun), do: :ok

  defp format_time(us) when us < 1000, do: "#{us}μs"
  defp format_time(us) when us < 1_000_000, do: "#{div(us, 1000)}ms #{rem(us, 1000)}μs"
  defp format_time(us), do: "#{div(us, 1_000_000)}s #{rem(us, 1000)}ms"

  # def send_notification(args \\ args()) do
  #   T.PushNotifications.APNSJob.perform(%Oban.Job{args: args})
  # end

  def feed_setup do
    {:ok, _pid} = T.Feeds.FeedCache.start_link([])
    feed_demo_users()
  end

  def feed_demo_users do
    story = story() |> :erlang.term_to_binary()

    # binary story (story = story() |> :erlang.term_to_binary())
    # 5 MB for 10_000 -> 100 MB for 200_000 -> 1 GB for 2_000_000
    # map story (story = story())
    # 50 MB for 10_000 -> 100 MB for 20_000 -> 1 GB for 200_000
    1..10000
    |> Enum.map(fn _ ->
      user_id = Ecto.Bigflake.UUID.bingenerate()
      session_id = Ecto.Bigflake.UUID.bingenerate()
      {user_id, session_id, %{gender: "M", preferences: ["F"], name: "Ruslan", story: story}}
    end)
    |> T.Feeds.FeedCache.put_many_users()
  end

  def me do
    T.Repo.get!(T.Accounts.User, "0000017c-1494-edea-0242-ac1100020000")
  end

  def my_devices do
    T.Accounts.list_apns_devices("0000017c-1494-edea-0242-ac1100020000")
  end

  def others_devices do
    T.Accounts.APNSDevice
    |> join(:inner, [d], u in T.Accounts.User, on: d.user_id == u.id and not is_nil(u.apple_id))
    |> T.Repo.all()
    |> Enum.map(fn %{device_id: device_id} = device ->
      %{device | device_id: Base.encode16(device_id)}
    end)
  end

  def eh(i) do
    device_id = "6c0b96b86473d407517140ab898490309909395dd144cd30a4668affc1a1ec6b"
    topic = "since.app.ios"

    payload = %{
      "aps" => %{
        "alert" => %{
          "title" => "Your app has been removed from Google Play",
          "body" =>
            "We recommend that you watch this video which explains the various policy review outcomes, gives some common examples of what might cause a violation, and explains next steps for getting your flagged app or game back on Google Play."
        }
      }
    }

    req = T.APNS.Request.new(device_id, topic, payload, _env = :prod)
    T.APNS.push(req)
  end

  @task_sup __MODULE__.TaskSupervisor

  def ensure_task_supervisor do
    Task.Supervisor.start_link(name: @task_sup)
  end

  def async_stream(enum, fun) do
    ensure_task_supervisor()
    opts = [ordered: false, max_concurrency: 100]
    Task.Supervisor.async_stream(@task_sup, enum, fun, opts)
  end

  def eh2(count) do
    1..count
    |> async_stream(fn i -> eh(i) end)
    |> Enum.reduce([], fn
      {:ok, :ok}, acc -> acc
      {:ok, error}, acc -> [error | acc]
    end)
    |> Enum.group_by(& &1, fn _ -> 1 end)
    |> Map.new(fn {error, counts} -> {error, Enum.sum(counts)} end)
  end

  def story do
    [
      %{
        "background" => %{"s3_key" => "1e08a6a1-c99a-4ac0-bc75-aef5e03fab8a"},
        "labels" => [
          %{
            "answer" => "Moscow",
            "position" => [16.39473684210526, 653.8865836791149],
            "question" => "city",
            "rotation" => 0,
            "value" => "Moscow",
            "zoom" => 1
          },
          %{
            "answer" => "1992-06-15T09:29:34Z",
            "position" => [17.76315789473683, 711.5131396957124],
            "question" => "birthdate",
            "rotation" => 0,
            "value" => "29",
            "zoom" => 1
          },
          %{
            "answer" => "marketing",
            "position" => [17.894736842105278, 768.5200553250346],
            "question" => "occupation",
            "rotation" => 0,
            "value" => "marketing",
            "zoom" => 1
          }
        ],
        "size" => [414, 896]
      },
      %{
        "background" => %{"s3_key" => "7b2ee4ac-f52f-4428-8da5-7538cab82ca2"},
        "labels" => [
          %{
            "answer" => "dog",
            "position" => [32.45421914384576, 508.55878284923926],
            "question" => "pets",
            "rotation" => 0,
            "value" => "dog",
            "zoom" => 1
          },
          %{
            "answer" => "",
            "position" => [30.007430073955632, 125.42931999400341],
            "question" => "height",
            "rotation" => -0.1968919380719123,
            "value" => "169 cm",
            "zoom" => 0.929552717754467
          }
        ],
        "size" => [414, 896]
      },
      %{
        "background" => %{"s3_key" => "030cf497-eabc-40e8-9e25-22f0549d5828"},
        "labels" => [
          %{
            "answer" => "politics",
            "position" => [255.18867086246476, 172.7136929460581],
            "question" => "interests",
            "rotation" => 0,
            "value" => "politics",
            "zoom" => 1
          },
          %{
            "answer" => "culture and art",
            "position" => [188.0263157894737, 231.47884213914443],
            "question" => "books",
            "rotation" => 0,
            "value" => "culture and art",
            "zoom" => 1
          }
        ],
        "size" => [414, 896]
      },
      %{
        "background" => %{"s3_key" => "8ecc0c2c-89fb-437f-bfae-4893cba3c7fc"},
        "labels" => [
          %{
            "answer" => "The Sopranos",
            "position" => [9.407094262700014, 362.32365145228215],
            "question" => "tv_shows",
            "rotation" => 0,
            "value" => "The Sopranos",
            "zoom" => 1
          }
        ],
        "size" => [414, 896]
      }
    ]
  end

  def gc do
    Enum.each(Process.list(), fn pid -> :erlang.garbage_collect(pid) end)
  end
end
