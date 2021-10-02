defmodule Dev do
  # alias T.PushNotifications.APNS

  # click + -> can add session by picking user and inputting duration -> table updates
  # can select user to impersonate, if selected, can invite, call etc. based on status
  # search

  import Ecto.Query

  def args do
    %{
      "data" => %{
        "match_id" => "0000017b-b277-cbad-0242-ac1100020000"
      },
      "device_id" => "E069BD8A7CFF5BC34656C767209697AE3DB3B26E03E1252FA79EA7A773F75783",
      "env" => "sandbox",
      "locale" => nil,
      "template" => "timeslot_started",
      "topic" => "since.app.ios"
    }
  end

  # def send_notification(args \\ args()) do
  #   T.PushNotifications.APNSJob.perform(%Oban.Job{args: args})
  # end

  def me do
    T.Repo.get!(T.Accounts.User, "0000017c-1494-edea-0242-ac1100020000")
  end

  def my_devices do
    T.Accounts.list_apns_devices("0000017c-1494-edea-0242-ac1100020000")
  end

  def token do
    "eyJhbGciOiJFUzI1NiIsImtpZCI6IkRHN0pDNzQyMjciLCJ0eXAiOiJKV1QifQ.eyJhdWQiOiJhcHBlbCIsImV4cCI6MTYzMzE4ODc1MywiaWF0IjoxNjMzMTg1MTUzLCJpc3MiOiI1MjVWQ1M3UEZVIiwianRpIjoiMnFsM3Fma3BxdWhyaGNxa2kwMDAwODYxIiwibmJmIjoxNjMzMTg1MTUzfQ.kLroByuVYgaiIr8rK5onMML-gW9i3ifTmYk670EG0o8HHwDoFVfbSFCUM550EnE19OvgbpQrGm4Dt2jhgxB-wQ"
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
    T.APNS.push(req, token())
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

  # def send_notification do
  #   for device <- others_devices() do
  #     %{device_id: device_id, env: env, topic: topic} = device

  #     notification = %Pigeon.APNS.Notification{
  #       device_token: device_id,
  #       payload: %{
  #         "aps" => %{
  #           "alert" => %{
  #             "title" => "Мы стали новее",
  #             "body" =>
  #               "Привет! Пожалуйста, обнови приложение, чтобы продолжить им пользоваться 👀❤️"
  #           }
  #         }
  #       },
  #       push_type: "alert",
  #       topic: topic
  #     }

  #     T.PushNotifications.APNS.Pigeon.push(notification, apns_env(env))
  #   end
  # end

  # defp apns_env("prod"), do: :prod
  # defp apns_env("sandbox"), do: :dev

  def run do
    # notifications =
    #   devices()
    #   |> Enum.map(fn device ->
    #     %Pigeon.APNS.Notification{
    #       device_token: device.device_id,
    #       push_type: "background",
    #       topic: "since.app.ios"
    #     }
    #   end)

    # Pigeon.APNS.push(notifications, to: :prod)

    # args = %{
    #   "data" => %{"name" => "Rail", "user_id" => "0000017b-86b5-039d-0242-ac1100020000"},
    #   "device_id" => "706e1db8abb8205351eefa0b5be078149f8f5f277a99dda0601bc8d8647a56cd",
    #   "env" => "sandbox",
    #   "locale" => nil,
    #   "template" => "invite",
    #   "topic" => "since.app.ios"
    # }

    # devices = [
    #   "6ad0ce59461fc5a491a94bc012f03bc1c5e2c36ea6474f31ce419830e09b95f7",
    #   "706e1db8abb8205351eefa0b5be078149f8f5f277a99dda0601bc8d8647a56cd",
    #   "3546b5d371127f6cb30c4df4b596bbfba0ab6f62bfb9294f6a533f9e119e0661",
    #   "8c38eb244937e9bb057ac6372d343111a73bb264e94484d899059bdaef234a10"
    # ]

    # n =
    #   Enum.map(devices, fn d ->
    #     %Pigeon.APNS.Notification{
    #       device_token: d,
    #       payload: %{
    #         "aps" => %{
    #           "alert" => %{"title" => "Rail invited you for a call"}
    #         },
    #         "type" => "invite",
    #         "user_id" => "0000017b-86b5-039d-0242-ac1100020000"
    #       },
    #       push_type: "alert",
    #       topic: "since.app.ios"
    #     }
    #   end)

    # Pigeon.APNS.push(n, to: :dev)

    # T.PushNotifications.APNSJob.perform(%Oban.Job{args: args})
  end

  def devices do
    T.Accounts.APNSDevice
    |> T.Repo.all()
    |> Enum.map(fn device ->
      %{device | device_id: Base.encode16(device.device_id)}
    end)
  end
end

defmodule FeedCache do
  use GenServer
  require Logger

  def setup do
    {:ok, _pid} = FeedCache.start_link([])
    FeedCache.demo_user()
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

  def demo_user do
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
    |> FeedCache.put_many_users()
  end

  # def compress_story([%{"background" => %"s3_key" => key} | rest]) do
  #   s3_key = Ecto.UUID.dump!(s3_key)

  # end

  # def compress_story([]) do
  #   <<>>
  # end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @session2profiles :session2profiles
  @profiles :profiles

  @impl true
  def init(_opts) do
    for my_gender <- ["M", "F"], want_gender <- ["M", "F"] do
      :ets.new(table(my_gender, want_gender), [:named_table, :ordered_set])
    end

    # TODO compare perf with duplicate_bag (~10% faster)
    :ets.new(@session2profiles, [:named_table])
    :ets.new(@profiles, [:named_table])

    {:ok, nil}
  end

  def table(my_gender, want_gender)
  def table("M", "F"), do: :active_FM
  def table("F", "M"), do: :active_MF
  def table("M", "M"), do: :active_MM
  def table("F", "F"), do: :active_FF

  @spec fetch_feed(binary, String.t(), [String.t()], pos_integer()) ::
          {binary, [{binary, String.t(), String.t(), [map]}]}
  def fetch_feed(cursor \\ nil, gender, preferences, limit \\ 10)

  # with cursor and single gender preference
  def fetch_feed(<<_::192>> = cursor, gender, [preference], limit) do
    do_fetch_feed(table(gender, preference), cursor, limit, _acc = [])
  end

  # with two cursors and two gender preferences
  def fetch_feed(<<c1::24-bytes, c2::24-bytes>>, gender, [p1, p2], limit) do
    tables = [table(gender, p1), table(gender, p2)]
    cursors = [c1, c2]
    do_fetch_feed_cycle(tables, tables, cursors, cursors, limit, _acc = [])
  end

  # with no cursor and single gender preference
  def fetch_feed(nil = _cursor, gender, [preference], limit) do
    do_fetch_feed(table(gender, preference), _cursor = <<0::192>>, limit, _acc = [])
  end

  defp do_fetch_feed(tab, cursor, limit, acc) when limit > 0 do
    case :ets.next(tab, cursor) do
      <<_geohash::64, session_id::16-bytes>> = cursor ->
        do_fetch_feed(tab, cursor, limit - 1, [fetch_feed_profile(session_id) | acc])

      :"$end_of_table" ->
        {cursor, :lists.reverse(acc)}
    end
  end

  defp do_fetch_feed(_tab, cursor, 0, acc) do
    {cursor, :lists.reverse(acc)}
  end

  defp do_fetch_feed_cycle(
         [tab | rest_tab],
         orig_tables,
         [cursor | rest_cursor],
         cursors,
         limit,
         acc
       )
       when limit > 0 do
    case :ets.next(tab, cursor) do
      <<_geohash::64, session_id::16-bytes>> = cursor ->
        acc = [fetch_feed_profile(session_id) | acc]
        # TODO I don't like ++
        do_fetch_feed_cycle(rest_tab, orig_tables, rest_cursor ++ [cursor], limit, acc)

      :"$end_of_table" ->
        do_fetch_feed_cycle(rest_tab, List.delete(orig_tables, tab), rest_cursor, limit, acc)
    end
  end

  defp do_fetch_feed_cycle([], _tables, [], _limit, acc) do
    {_cursors = <<>>, acc}
  end

  defp do_fetch_feed_cycle(_tables, _tables, _cursors, 0, acc) do
    {_cursors = <<>>, :lists.reverse(acc)}
  end

  def fetch_feed_profile(<<_::128>> = session_id) do
    [{^session_id, user_id}] = :ets.lookup(@session2profiles, session_id)
    [{^user_id, _name, _gender, story} = profile] = :ets.lookup(@profiles, user_id)
    put_elem(profile, 3, :erlang.binary_to_term(story))
  end

  def fetch_feed_profile(<<_::288>> = session_id) do
    session_id
    |> Ecto.UUID.dump!()
    |> fetch_feed_profile()
  end

  def put_user(<<_::128>> = user_id, <<_::128>> = session_id, data) do
    GenServer.call(__MODULE__, {:put, user_id, session_id, data})
  end

  def put_many_users(users) do
    GenServer.call(__MODULE__, {:put, users})
  end

  def remove_session(session_id) do
    GenServer.call(__MODULE__, {:remove, session_id})
  end

  def stats do
    %{
      profiles: :ets.info(@profiles)
    }
  end

  @impl true
  def handle_call({:put, <<_::128>> = user_id, <<_::128>> = session_id, data}, _from, state) do
    insert_user(user_id, session_id, data)
    {:reply, :ok, state}
  end

  def handle_call({:put, users}, _from, state) when is_list(users) do
    Enum.each(users, fn {user_id, session_id, data} -> insert_user(user_id, session_id, data) end)
    {:reply, :ok, state}
  end

  def handle_call({:remove, <<_::128>> = session_id}, _from, state) do
    # TODO improve, only delete from tables that have the user, need to know gender preferences
    for g1 <- ["M", "F"],
        g2 <- ["M", "F"],
        do: :ets.delete(table(g1, g2), <<0::64, session_id::bytes>>)

    [{^session_id, user_id}] = :ets.lookup(@session2profiles, session_id)
    :ets.delete(@session2profiles, session_id)
    :ets.delete(@profiles, user_id)

    {:reply, :ok, state}
  end

  def handle_call(message, _from, state) do
    Logger.error("unhandled message in FeedCache: " <> inspect(message))
    {:reply, {:error, :badarg}, state}
  end

  defp insert_user(<<_::128>> = user_id, <<_::128>> = session_id, data) do
    %{gender: gender, preferences: prefs, name: name, story: story} = data

    :ets.insert(@profiles, {user_id, name, gender, story})
    :ets.insert(@session2profiles, {session_id, user_id})
    for pref <- prefs, do: :ets.insert(table(pref, gender), {<<0::64, session_id::bytes>>})
  end
end
