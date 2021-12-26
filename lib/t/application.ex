defmodule T.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  def start(_type, _args) do
    children =
      [
        {Task.Supervisor, name: T.TaskSupervisor},
        APNS.Token,
        # T.PromEx,
        # TODO add apple keys endpoint and twilio (possibly aws as well)
        {Finch,
         name: T.Finch,
         pools: %{
           "https://api.development.push.apple.com" => [protocol: :http2],
           "https://api.push.apple.com" => [protocol: :http2, count: 1]
         }},
        T.Twilio,
        {Phoenix.PubSub, name: T.PubSub},
        unless_disabled(T.Media.Static),
        TWeb.CallTracker,
        TWeb.Presence,
        TWeb.UserSocket.Monitor,
        T.Repo,
        unless_disabled(T.Feeds.SeenPruner),
        unless_disabled(T.Matches.MatchExpirer),
        unless_disabled(T.PushNotifications.ScheduledPushes),
        TWeb.Endpoint,
        TWeb.Telemetry,
        maybe_migrator(),
        {Oban, oban_config()},
        Supervisor.child_spec({Task, &T.Release.mark_ready/0}, id: :readiness_notifier)
      ]
      |> Enum.reject(&is_nil/1)

    # TODO wait with :locus.await_loader(@db) before readiness_notifier
    maybe_setup_locus()

    # Only attach the telemetry logger when we aren't in an IEx shell
    unless Code.ensure_loaded?(IEx) && IEx.started?() do
      Oban.Telemetry.attach_default_logger(:info)
      T.ObanReporter.attach()
    end

    opts = [strategy: :one_for_one, name: T.Supervisor]

    with {:ok, _pid} = result <- Supervisor.start_link(children, opts) do
      maybe_add_pusbub_logger_backend()
      result
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    TWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  # Conditionally disable crontab, queues, or plugins here.
  defp oban_config do
    config = Application.get_env(:t, Oban)

    # Prevent running queues or scheduling jobs from an iex console.
    if Code.ensure_loaded?(IEx) and IEx.started?() do
      config
      |> Keyword.put(:queues, false)
      |> Keyword.put(:plugins, false)
    else
      config
    end
  end

  defp maybe_migrator do
    if Application.get_env(:t, :run_migrations_on_start?) do
      Logger.info("Running migrations")
      T.Release.Migrator
    end
  end

  defp maybe_setup_locus do
    if key = Application.get_env(:t, :maxmind_license_key) do
      T.Location.setup(key)
    end
  end

  defp maybe_add_pusbub_logger_backend do
    if _config = Application.get_env(:logger, T.PubSubLoggerBackend) do
      {:ok, _pid} = Logger.add_backend(T.PubSubLoggerBackend)
    end
  end

  defp disabled?(mod) when is_atom(mod) do
    get_in(Application.get_env(:t, mod), [:disabled?])
  end

  defp unless_disabled(mod) when is_atom(mod) do
    unless disabled?(mod), do: mod
  end
end
