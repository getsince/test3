import Config

config :t, ecto_repos: [T.Repo]
config :t, T.Repo, types: T.PostgresTypes

config :phoenix, :json_library, Jason
config :sentry, client: T.Sentry.FinchHTTPClient

config :sentry,
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
