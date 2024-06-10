import Config

config :since, Since.Media.Client, adapter: Since.Media.S3Client
config :since, Since.Bot, adapter: Since.Bot.API
config :since, Since.PushNotifications.APNS, adapter: Since.PushNotifications.APNS.FinchAdapter
config :since, Since.Accounts.AppleSignIn, adapter: Since.Accounts.AppleSignIn.HTTPAdapter

config :since, SinceWeb.Endpoint, cache_static_manifest: "priv/static/cache_manifest.json"
