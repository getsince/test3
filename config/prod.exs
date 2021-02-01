import Config

config :t, T.Accounts.UserNotifier, adapter: T.SMS

config :t, TWeb.Endpoint, cache_static_manifest: "priv/static/cache_manifest.json"
