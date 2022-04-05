defmodule T.MixProject do
  use Mix.Project

  def project do
    [
      app: :t,
      version: "0.1.6",
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      releases: releases()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {T.Application, []},
      extra_applications: extra_applications(Mix.env())
    ]
  end

  defp extra_applications(:prod), do: [:logger, :runtime_tools, :os_mon]
  defp extra_applications(_env), do: [:logger, :runtime_tools]

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "dev"]
  defp elixirc_paths(_env), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.5"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:ecto_sql, "~> 3.6"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_live_view, "~> 0.17.5"},
      {:phoenix_live_dashboard, "~> 0.6.2"},
      {:ecto_psql_extras, "~> 0.2"},
      {:telemetry_metrics, "~> 0.4"},
      {:telemetry_poller, "~> 1.0.0"},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.5"},
      {:oban, "~> 2.3"},
      {:remote_ip, "~> 1.0.0"},
      {:mox, "~> 1.0", only: :test},
      {:ex_machina, "~> 2.4", only: :test},
      {:assertions, "~> 0.19.0", only: :test},
      {:sentry, "~> 8.0"},
      {:bigflake, "0.5.0"},
      {:imgproxy, "~> 2.0"},
      {:rexbug, "~> 1.0"},
      {:geo_postgis, "~> 3.4"},
      {:finch, "~> 0.10.1"},
      {:locus, "~> 2.2"},
      # TODO
      {:cloud_watch, github: "getsince/cloud_watch", branch: "drop-httpoison"},
      {:benchee, "~> 1.0", only: :bench},
      {:dialyxir, "~> 1.1", only: :dev, runtime: false},
      {:jose, "~> 1.11"},
      {:nimble_csv, "~> 1.2"},
      {:libcluster, "~> 3.3"},
      {:aws, "~> 0.10.1"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "cmd npm ci --prefix assets"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      sentry_recompile: ["compile", "deps.compile sentry --force"],
      "assets.deploy": [
        "cmd npm ci --prefix assets",
        "cmd npm run deploy:css --prefix assets",
        "cmd npm run deploy:js --prefix assets",
        "phx.digest"
      ]
    ]
  end

  defp releases do
    config = [
      include_executables_for: [:unix],
      steps: if(System.get_env("ARCHIVE_RELEASE"), do: [:assemble, :tar]),
      version: System.get_env("RELEASE_VERSION"),
      path: System.get_env("RELEASE_PATH")
    ]

    config = Enum.reject(config, fn {_k, v} -> is_nil(v) end)
    [t: config]
  end
end
