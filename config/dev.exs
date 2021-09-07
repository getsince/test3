import Config

# For development, we enable code reloading.
config :t, TWeb.Endpoint, code_reloader: true

config :t, T.Media.Client, adapter: T.Media.S3Client
config :t, T.Bot, adapter: T.Bot.API
config :t, T.PushNotifications.APNS, adapter: T.PushNotifications.APNS.Pigeon
config :t, T.Twilio, adapter: T.Twilio.HTTP

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime
