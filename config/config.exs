import Config

config :t, ecto_repos: [T.Repo]
config :t, T.Repo, types: T.PostgresTypes

config :phoenix, :json_library, Jason
config :pigeon, json_library: Jason

config :ex_aws,
  http_client: T.FinchHttpClient

config :t, T.Music, adapter: T.Music.API
config :t, T.Media.Client, adapter: T.Media.S3Client
config :t, T.Bot, adapter: T.Bot.API

config :sentry,
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
