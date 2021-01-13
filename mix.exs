defmodule T.MixProject do
  use Mix.Project

  def project do
    [
      app: :t,
      version: "0.1.6",
      elixir: "~> 1.11",
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
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.5.3"},
      {:phoenix_ecto, "~> 4.1"},
      {:ecto_sql, "~> 3.4"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_live_dashboard, "~> 0.4.0"},
      {:telemetry_metrics, "~> 0.4"},
      {:telemetry_poller, "~> 0.4"},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:ex_aws, "~> 2.1"},
      {:ex_aws_s3, "~> 2.0"},
      {:ex_aws_sns, "~> 2.1"},
      {:ex_aws_ses, "~> 2.1"},
      {:hackney, "~> 1.9"},
      {:sweet_xml, "~> 0.6"},
      {:plug_attack, "~> 0.3"},
      # TODO
      {:bamboo_ses, "~> 0.1.6"},
      {:bamboo, "~> 1.6"},
      {:oban, "~> 2.3"},
      {:remote_ip, "~> 0.2.1"},
      {:ex_phone_number, "~> 0.2"},
      # TODO
      {:passwordless_auth, "~> 0.3.0"},
      {:mox, "~> 1.0", only: :test},
      {:ex_machina, "~> 2.4", only: :test},
      {:assertions, "~> 0.18.1", only: :test},
      {:timex, "~> 3.6"},
      {:httpoison, "~> 1.7"},
      # {:pigeon, "~> 1.5", runtime: false},
      # {:kadabra, "~> 0.4.4"},
      {:sentry, "~> 8.0", runtime: false},
      {:bigflake, "0.5.0"}
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
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      sentry_recompile: ["compile", "deps.compile sentry --force"]
    ]
  end

  defp releases do
    [
      t: [
        include_executables_for: [:unix]
      ]
    ]
  end
end
