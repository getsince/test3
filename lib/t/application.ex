defmodule T.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  def start(_type, _args) do
    children =
      [
        {Phoenix.PubSub, name: T.PubSub},
        TWeb.Endpoint,
        T.Repo,
        TWeb.Telemetry,
        maybe_migrator(),
        {Oban, oban_config()},
        Supervisor.child_spec({Task, &T.Release.mark_ready/0}, id: :readiness_notifier)
      ]
      |> Enum.reject(&is_nil/1)

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
    Application.get_env(:t, Oban)
  end

  defp maybe_migrator do
    if Application.get_env(:t, :run_migrations_on_start?) do
      Logger.info("Running migrations")
      T.Release.Migrator
    end
  end
end
