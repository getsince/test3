import Config

config :t, T.Media.Client, adapter: T.Media.S3Client
config :t, T.Bot, adapter: T.Bot.API
config :t, T.APNS, adapter: T.APNS.FinchAdapter
config :t, T.Twilio, adapter: T.Twilio.HTTP

config :t, TWeb.Endpoint, cache_static_manifest: "priv/static/cache_manifest.json"
