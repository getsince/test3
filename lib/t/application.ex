defmodule T.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  def start(_type, _args) do
    sometimes_children = [
      {Task.Supervisor, name: T.TaskSupervisor},
      {Finch,
       name: T.Finch,
       pools: %{
         # TODO add apple keys endpoint and twilio (possibly aws as well)
         "https://api.development.push.apple.com" => [protocol: :http2],
         "https://api.push.apple.com" => [protocol: :http2, count: 1]
       }},
      T.APNS.Token,
      T.Twilio,
      {Phoenix.PubSub, name: T.PubSub},
      unless_disabled(T.Media.Static),
      TWeb.Presence,
      TWeb.UserSocket.Monitor,
      T.Repo,
      maybe_migrator(),
      unless_disabled(T.Feeds.FeedCache),
      TWeb.Endpoint,
      unless_disabled(T.Feeds.ActiveSessionPruner),
      TWeb.Telemetry,
      {Oban, oban_config()}
    ]

    children = Enum.reject(sometimes_children, &is_nil/1)
    opts = [strategy: :one_for_one, name: T.Supervisor]

    with {:ok, _pid} = result <- Supervisor.start_link(children, opts) do
      maybe_add_pusbub_logger_backend()

      # TODO wait with :locus.await_loader(@db) before readiness_notifier
      maybe_setup_locus()

      # Only attach the telemetry logger when we aren't in an IEx shell
      unless Code.ensure_loaded?(IEx) && IEx.started?() do
        Oban.Telemetry.attach_default_logger(:info)
        T.ObanReporter.attach()
      end

      T.Release.mark_ready()
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

  defp unless_disabled(mod) do
    unless disabled?(mod), do: mod
  end
end
