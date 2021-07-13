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
        T.PromEx,
        {Finch, name: T.Finch},
        T.Twilio,
        {Phoenix.PubSub, name: T.PubSub},
        T.Media.Static,
        TWeb.Presence,
        TWeb.UserSocket.Monitor,
        T.Matches.Yo,
        TWeb.Endpoint,
        T.Repo,
        T.Feeds.SeenPruner,
        T.Accounts.SMSCodePruner,
        TWeb.Telemetry,
        maybe_migrator(),
        {Oban, oban_config()},
        Supervisor.child_spec({Task, &T.Release.mark_ready/0}, id: :readiness_notifier)
      ]
      |> Enum.reject(&is_nil/1)

    maybe_setup_locus()

    :telemetry.attach_many(
      "oban-errors",
      [[:oban, :job, :exception], [:oban, :circuit, :trip]],
      &T.ObanErrorReporter.handle_event/4,
      %{}
    )

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: T.Supervisor]
    Supervisor.start_link(children, opts)
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
      |> Keyword.put(:crontab, false)
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
end
