import Config

config :t, T.Accounts.UserNotifier, adapter: T.SMS
config :t, T.Media.Client, adapter: T.Media.S3Client
config :t, T.Bot, adapter: T.Bot.API
config :t, T.PushNotifications.APNS, adapter: T.PushNotifications.APNS.Pigeon

config :t, TWeb.Endpoint, cache_static_manifest: "priv/static/cache_manifest.json"
