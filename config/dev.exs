import Mix.Config

# For development, we enable code reloading.
config :t, TWeb.Endpoint, code_reloader: true

config :t, T.Accounts.UserNotifier, adapter: T.Accounts.LocalUserNotifier

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# https://github.com/ajvondrak/remote_ip#logging
config :logger, compile_time_purge_matching: [[application: :remote_ip]]
