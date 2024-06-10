defmodule DevAPNS do
  alias Since.PushNotifications.APNS, as: Push

  def ruslan_id do
    "0000017c-a7df-c36e-0242-ac1100040000"
  end

  # %Since.Accounts.APNSDevice{
  #   __meta__: #Ecto.Schema.Metadata<:loaded, "apns_devices">,
  #   device_id: "2DAE2436E3D183F3683907FACD8EF8D515FAF541CA55A265A4144371C2A83137",
  #   env: "prod",
  #   inserted_at: ~N[2021-10-22 12:00:32],
  #   locale: "en",
  #   token: #Ecto.Association.NotLoaded<association :token is not loaded>,
  #   token_id: "0000017c-a7df-c377-0242-ac1100040000",
  #   topic: "since.app.ios",
  #   updated_at: ~N[2021-10-22 12:00:32],
  #   user: #Ecto.Association.NotLoaded<association :user is not loaded>,
  #   user_id: "0000017c-a7df-c36e-0242-ac1100040000"
  # }
  def apns_device do
    import Ecto.Query

    Since.Accounts.APNSDevice
    |> where(user_id: ^ruslan_id())
    |> Since.Repo.one!()
    |> then(fn %{device_id: id} = device -> %{device | device_id: Base.encode16(id)} end)
  end

  # %{
  #   device_id: "2DAE2436E3D183F3683907FACD8EF8D515FAF541CA55A265A4144371C2A83137",
  #   env: "prod",
  #   payload: %{
  #     "aps" => %{
  #       "alert" => %{"body" => "Come look!", "title" => "That's a match!"},
  #       "badge" => 1
  #     },
  #     "type" => "match"
  #   },
  #   push_type: "alert",
  #   topic: "since.app.ios"
  # }
  def templated_alert(template, data \\ %{}, apns_device \\ apns_device()) do
    payload = Push.build_alert_payload(template, data)
    %Since.Accounts.APNSDevice{device_id: device_id, topic: topic, env: "prod"} = apns_device
    APNS.build_notification(device_id, topic, payload, :prod)
  end

  def push_templated_alert(template, data \\ %{}, apns_device \\ apns_device()) do
    template
    |> templated_alert(data, apns_device)
    |> APNS.push(Since.Finch)
  end

  # run one of
  #   Gettext.put_locale("en")
  #   Gettext.put_locale("ru")
  # to change locale for the current process
  def push_all_templates do
    templates = [
      "match",
      {"invite", %{"user_id" => "asdf", "name" => "inviter name"}}
    ]

    Enum.map(templates, fn template ->
      case template do
        {template, data} -> push_templated_alert(template, data)
        template when is_binary(template) -> push_templated_alert(template)
      end
    end)
  end

  # too_many_concurrent_requests tracing
  # https://gist.github.com/ruslandoga/8332cc8a2cf260c4c3a6d23386c8a06a

  def notification do
    APNS.build_notification(
      _device_id = "2DAE2436E3D183F3683907FACD8EF8D515FAF541CA55A265A4144371C2A83137",
      _topic = "since.app.ios",
      _payload = %{
        "aps" => %{
          "alert" => %{"body" => "Come look!", "title" => "That's a match!"},
          "badge" => 1
        },
        "type" => "match"
      },
      _env = :prod
    )
  end

  def retrace do
    Rexbug.stop()

    Rexbug.start(["Mint.HTTP2 :: return", "Mint.HTTP2.Frame :: return"],
      time: 1_000_000,
      msgs: 100_000
    )
  end

  def mint_conn do
    [{Since.Finch.PIDPartition0, pid, :worker, [Registry.Partition]}] =
      Supervisor.which_children(Since.Finch)

    pid
    |> :sys.get_state()
    |> :ets.tab2list()
    |> Enum.find_value(fn
      {conn_pid, {:https, "api.push.apple.com", 443}, _ref, _} -> conn_pid
      _other -> nil
    end)
  end

  def kill_conn do
    Process.exit(mint_conn(), :killed)
  end

  # kill_conn()
  # retrace()
  # too_many_concurrent_requests()
  def too_many_concurrent_requests do
    task_supervisor = DevAPNS.TaskSupervisor
    Task.Supervisor.start_link(name: task_supervisor)
    n = notification()

    task_supervisor
    |> Task.Supervisor.async_stream(
      1..3,
      fn i -> {i, APNS.push(n, Since.Finch)} end,
      max_concurrency: 100,
      ordered: false
    )
    |> Enum.into([])
  end
end
