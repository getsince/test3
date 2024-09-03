import Config

# For development, we enable code reloading.
config :since, SinceWeb.Endpoint, code_reloader: true

config :since, Since.Media.Client, adapter: Since.Media.S3Client
config :since, Since.Bot, adapter: Since.Bot.API
config :since, Since.PushNotifications.APNS, adapter: Since.PushNotifications.APNS.FinchAdapter
config :since, Since.Accounts.AppleSignIn, adapter: Since.Accounts.AppleSignIn.HTTPAdapter

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime
