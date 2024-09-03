defmodule Since.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  def start(_type, _args) do
    children =
      [
        {Task.Supervisor, name: Since.TaskSupervisor},
        APNS.Token,
        AppStore.Token,
        Since.Spotify,
        maybe_finch(),
        {Phoenix.PubSub, name: Since.PubSub},
        unless_disabled(Since.Media.Static),
        SinceWeb.UserSocket.Monitor,
        maybe_repo(),
        maybe_migrator(),
        maybe_oban(),
        maybe_periodics(),
        maybe_endpoint(),
        # maybe_app_store_notifications(),
        SinceWeb.Telemetry,
        Supervisor.child_spec({Task, &Since.Release.mark_ready/0}, id: :readiness_notifier)
      ]
      |> List.flatten()
      |> Enum.reject(&is_nil/1)

    # TODO wait with :locus.await_loader(@db) before readiness_notifier
    maybe_setup_locus()

    # Only attach the telemetry logger when we aren't in an IEx shell
    unless Code.ensure_loaded?(IEx) && IEx.started?() do
      Oban.Telemetry.attach_default_logger(:info)
      Since.ObanReporter.attach()
    end

    opts = [strategy: :one_for_one, name: Since.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    SinceWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  # Conditionally disable crontab, queues, or plugins here.
  defp oban_config do
    config = Application.get_env(:since, Oban)

    # Prevent running queues or scheduling jobs from an iex console.
    if Code.ensure_loaded?(IEx) and IEx.started?() do
      config
      |> Keyword.put(:queues, false)
      |> Keyword.put(:plugins, false)
    else
      config
    end
  end

  defp repo_config do
    Application.get_env(:since, Since.Repo)
  end

  defp repo_url do
    get_in(repo_config(), [:url])
  end

  defp maybe_oban do
    if repo_url() do
      {Oban, oban_config()}
    else
      Logger.warning("not starting oban due to missing repo url info")
      nil
    end
  end

  defp maybe_periodics do
    unless_disabled(Since.Periodics)
  end

  defp maybe_finch do
    # TODO add apple keys endpoint (possibly aws as well)
    unless_disabled(
      {Finch,
       name: Since.Finch,
       pools: %{
         "https://api.development.push.apple.com" => [protocol: :http2],
         "https://api.push.apple.com" => [protocol: :http2, count: 1]
       }}
    )
  end

  defp maybe_endpoint do
    config = Application.get_env(:since, SinceWeb.Endpoint)

    if get_in(config, [:http]) do
      SinceWeb.Endpoint
    else
      Logger.warning("not starting web endpoint due to missing http info")
      nil
    end
  end

  defp maybe_repo do
    if repo_url() do
      Since.Repo
    else
      Logger.warning("not starting repo due to missing url info")
      nil
    end
  end

  defp maybe_migrator do
    if Application.get_env(:since, :run_migrations_on_start?) do
      Logger.info("Running migrations")
      Since.Release.Migrator
    end
  end

  defp maybe_setup_locus do
    if key = Application.get_env(:since, :maxmind_license_key) do
      Since.Location.setup(key)
    end
  end

  # defp maybe_app_store_notifications() do
  #   Logger.info("Fetching App Store Notifications")
  #   unless_disabled(AppStore.Notificator)
  # end

  defp disabled?(mod) when is_atom(mod) do
    get_in(Application.get_env(:since, mod), [:disabled?])
  end

  defp unless_disabled(mod) when is_atom(mod) do
    unless disabled?(mod), do: mod
  end

  defp unless_disabled({mod, _opts} = child) when is_atom(mod) do
    unless disabled?(mod), do: child
  end
end
