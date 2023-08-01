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
        maybe_events(),
        APNS.Token,
        AppStore.Token,
        T.Spotify,
        maybe_finch(),
        maybe_cluster(),
        {Phoenix.PubSub, name: T.PubSub},
        unless_disabled(T.Media.Static),
        TWeb.UserSocket.Monitor,
        maybe_repo(),
        maybe_migrator(),
        maybe_oban(),
        maybe_periodics(),
        maybe_workflows(),
        maybe_endpoint(),
        maybe_app_store_notifications(),
        TWeb.Telemetry,
        Supervisor.child_spec({Task, &T.Release.mark_ready/0}, id: :readiness_notifier)
      ]
      |> List.flatten()
      |> Enum.reject(&is_nil/1)

    # TODO wait with :locus.await_loader(@db) before readiness_notifier
    maybe_setup_locus()

    # Only attach the telemetry logger when we aren't in an IEx shell
    unless Code.ensure_loaded?(IEx) && IEx.started?() do
      Oban.Telemetry.attach_default_logger(:info)
      T.ObanReporter.attach()
    end

    node = node()

    unless node == :nonode@nohost do
      :logger.update_primary_config(%{metadata: %{node: node}})
    end

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
      |> Keyword.put(:queues, false)
      |> Keyword.put(:plugins, false)
    else
      config
    end
  end

  defp repo_config do
    Application.get_env(:t, T.Repo)
  end

  defp repo_url do
    get_in(repo_config(), [:url])
  end

  defp maybe_oban do
    if repo_url() do
      if T.Cluster.is_primary() do
        {Oban, oban_config()}
      else
        Logger.warning("not starting oban in read-replica region")
        nil
      end
    else
      Logger.warning("not starting oban due to missing repo url info")
      nil
    end
  end

  defp maybe_periodics do
    if T.Cluster.is_primary() do
      unless_disabled(T.Periodics)
    end
  end

  defp maybe_workflows do
    if T.Cluster.is_primary() do
      unless disabled?(T.Workflows) do
        [
          T.Workflows.Listener,
          {Registry,
           keys: :unique, name: T.Workflows.Registry, listeners: [T.Workflows.Listener]},
          T.Workflows.Supervisor
        ]
      end
    end
  end

  defp maybe_finch do
    # TODO add apple keys endpoint (possibly aws as well)
    unless_disabled(
      {Finch,
       name: T.Finch,
       pools: %{
         "https://api.development.push.apple.com" => [protocol: :http2],
         "https://api.push.apple.com" => [protocol: :http2, count: 1]
       }}
    )
  end

  defp maybe_endpoint do
    config = Application.get_env(:t, TWeb.Endpoint)

    if get_in(config, [:http]) do
      TWeb.Endpoint
    else
      Logger.warning("not starting web endpoint due to missing http info")
      nil
    end
  end

  defp maybe_repo do
    if repo_url() do
      T.Repo
    else
      Logger.warning("not starting repo due to missing url info")
      nil
    end
  end

  defp maybe_events do
    if config = Application.get_env(:t, T.Events) do
      {T.Events, config}
    else
      Logger.warning("not staring events due to missing config")
      nil
    end
  end

  defp maybe_migrator do
    if Application.get_env(:t, :run_migrations_on_start?) && T.Cluster.is_primary() do
      Logger.info("Running migrations")
      T.Release.Migrator
    end
  end

  defp maybe_setup_locus do
    if key = Application.get_env(:t, :maxmind_license_key) do
      T.Location.setup(key)
    end
  end

  defp maybe_cluster do
    if topologies = Application.get_env(:libcluster, :topologies) do
      {Cluster.Supervisor, [topologies, [name: T.Cluster.Supervisor]]}
    end
  end

  defp maybe_app_store_notifications() do
    if T.Cluster.is_primary() do
      Logger.info("Fetching App Store Notifications")
      unless_disabled(AppStore.Notificator)
    end
  end

  defp disabled?(mod) when is_atom(mod) do
    get_in(Application.get_env(:t, mod), [:disabled?])
  end

  defp unless_disabled(mod) when is_atom(mod) do
    unless disabled?(mod), do: mod
  end

  defp unless_disabled({mod, _opts} = child) when is_atom(mod) do
    unless disabled?(mod), do: child
  end
end
