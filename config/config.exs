import Config

config :t, ecto_repos: [T.Repo]
config :t, T.Repo, types: T.PostgresTypes

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :phoenix, :json_library, Jason

config :ex_aws, http_client: T.ExAws.FinchHttpClient
config :sentry, client: T.Sentry.FinchHTTPClient

config :sentry,
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()]

config :esbuild,
  version: "0.12.25",
  default: [
    args: ~w(js/app.js --bundle --target=es2016 --outdir=../priv/static/assets),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
