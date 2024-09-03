import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.

config :since, SinceWeb.Endpoint,
  render_errors: [view: SinceWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: Since.PubSub,
  live_view: [signing_salt: "Urm6JRcI"]

config :logger, :console, format: "$time $metadata[$level] $message\n"
# TODO
# metadata: [:request_id, :user_id, :remote_ip, :node]

config :logger,
  utc_log: true,
  # TODO
  # metadata: [:user_id, :remote_ip, :node],
  format: "$time $metadata[$level] $message\n"

config :sentry, environment_name: config_env()

config :since, Oban,
  repo: Since.Repo,
  plugins: [
    Oban.Plugins.Pruner,
    Oban.Plugins.Stager
  ],
  queues: [default: 10, apns: 100]

smoke? = !!System.get_env("SMOKE")

if config_env() == :prod and smoke? do
  config :since, Since.Media.Static, disabled?: true
  config :since, Since.Periodics, disabled?: true
  config :since, Finch, disabled?: true
end

if config_env() == :prod and not smoke? do
  config :logger, backends: [:console, Sentry.LoggerBackend]
  config :logger, :console, level: :info

  config :sentry, dsn: System.fetch_env!("SENTRY_DSN")

  config :since, Since.Bot,
    token: System.fetch_env!("TG_BOT_KEY"),
    room_id: System.fetch_env!("TG_ROOM_ID") |> String.to_integer()

  apns_topic = System.fetch_env!("APNS_TOPIC")
  team_id = System.fetch_env!("APNS_TEAM_ID")

  config :since, Since.PushNotifications.APNS, default_topic: apns_topic

  config :since, APNS,
    keys: [
      %{
        key: System.fetch_env!("SANDBOX_APNS_KEY"),
        key_id: System.fetch_env!("SANDBOX_APNS_KEY_ID"),
        team_id: team_id,
        topic: apns_topic,
        env: :dev
      },
      %{
        key: System.fetch_env!("PROD_APNS_KEY"),
        key_id: System.fetch_env!("PROD_APNS_KEY_ID"),
        team_id: team_id,
        topic: apns_topic,
        env: :prod
      }
    ]

  config :since, AppStore,
    key: %{
      key: System.fetch_env!("APP_STORE_KEY"),
      key_id: System.fetch_env!("APP_STORE_KEY_ID"),
      issuer_id: System.fetch_env!("APP_STORE_ISSUER_ID"),
      topic: apns_topic,
      env: :prod
    }

  config :since, run_migrations_on_start?: true

  config :since, Since.Repo,
    url: System.fetch_env!("DATABASE_URL"),
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "20"),
    ssl_opts: [verify: :verify_none]

  host = System.fetch_env!("HOST")

  # export CHECK_ORIGIN=//*.example.com,//*.пример.рф
  # results in check_origin = ["//*.example.com", "//*.пример.рф"]
  check_origin = "CHECK_ORIGIN" |> System.fetch_env!() |> String.split(",")

  config :since, SinceWeb.Endpoint,
    # For production, don't forget to configure the url host
    # to something meaningful, Phoenix uses this information
    # when generating URLs.
    url: [scheme: "https", host: host, port: 443],
    check_origin: check_origin,
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: String.to_integer(System.get_env("PORT") || "4000")
    ],
    secret_key_base: System.fetch_env!("SECRET_KEY_BASE"),
    server: true

  config :since, :dashboard,
    username: System.fetch_env!("DASHBOARD_USERNAME"),
    password: System.fetch_env!("DASHBOARD_PASSWORD")

  config :since, maxmind_license_key: System.fetch_env!("MAXMIND_LICENSE_KEY")

  config :imgproxy,
    prefix: System.fetch_env!("IMGPROXY_PREFIX"),
    key: System.fetch_env!("IMGPROXY_KEY"),
    salt: System.fetch_env!("IMGPROXY_SALT")

  config :since, :s3,
    access_key_id: System.fetch_env!("AWS_ACCESS_KEY_ID"),
    secret_access_key: System.fetch_env!("AWS_SECRET_ACCESS_KEY"),
    region: "eu-north-1"

  config :since, Since.Media,
    user_bucket: System.fetch_env!("AWS_S3_BUCKET"),
    user_cdn: System.fetch_env!("USER_CDN"),
    static_bucket: System.fetch_env!("AWS_S3_BUCKET_STATIC"),
    static_cdn: System.fetch_env!("STATIC_CDN"),
    media_bucket: System.fetch_env!("AWS_S3_BUCKET_MEDIA"),
    media_cdn: System.fetch_env!("MEDIA_CDN")

  config :since, Since.Spotify,
    client_id: System.fetch_env!("SPOTIFY_CLIENT_ID"),
    client_secret: System.fetch_env!("SPOTIFY_CLIENT_SECRET")
end

if config_env() == :dev do
  config :logger, :console, level: :warning
  config :logger, backends: [:console]

  config :since, APNS,
    keys: [
      %{
        key: System.fetch_env!("SANDBOX_APNS_KEY"),
        key_id: System.fetch_env!("SANDBOX_APNS_KEY_ID"),
        team_id: System.fetch_env!("APNS_TEAM_ID"),
        topic: System.fetch_env!("APNS_TOPIC"),
        env: :dev
      }
    ]

  config :since, AppStore,
    key: %{
      key: System.fetch_env!("APP_STORE_KEY"),
      key_id: System.fetch_env!("APP_STORE_KEY_ID"),
      issuer_id: System.fetch_env!("APP_STORE_ISSUER_ID"),
      topic: System.fetch_env!("APNS_TOPIC"),
      env: :dev
    }

  config :since, Since.PushNotifications.APNS, default_topic: System.fetch_env!("APNS_TOPIC")

  # For development, we disable any cache and enable
  # debugging.
  #
  # The watchers configuration can be used to run external
  # watchers to your application. For example, we use it
  # with esbuild to bundle .js and .css sources.
  config :since, SinceWeb.Endpoint,
    # Binding to loopback ipv4 address prevents access from other machines.
    # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
    http: [ip: {127, 0, 0, 1}, port: 4000],
    debug_errors: true,
    check_origin: false,
    secret_key_base: "G3Ln+/DGlLRcc0cFikD44j8AS16t7ab5g0CjqhGBkOz2ol5GjHemYelcDWDEjkw5",
    url: [host: "localhost"],
    # Watch static and templates for browser reloading.
    live_reload: [
      patterns: [
        ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
        ~r"priv/gettext/.*(po)$",
        ~r"lib/since_web/(live|views)/.*(ex)$",
        ~r"lib/since_web/templates/.*(eex)$"
      ]
    ],
    watchers: [
      yarn: ["watch:js", cd: Path.expand("../assets", __DIR__)],
      yarn: ["watch:css", cd: Path.expand("../assets", __DIR__)]
    ]

  # Configure your database
  config :since, Since.Repo,
    url: System.get_env("DATABASE_URL") || "ecto://postgres:postgres@localhost:5432/t_dev",
    show_sensitive_data_on_connection_error: true,
    pool_size: 10

  config :since, :dashboard,
    username: System.fetch_env!("DASHBOARD_USERNAME"),
    password: System.fetch_env!("DASHBOARD_PASSWORD")

  config :since, maxmind_license_key: System.fetch_env!("MAXMIND_LICENSE_KEY")

  config :imgproxy,
    prefix: System.fetch_env!("IMGPROXY_PREFIX"),
    key: System.fetch_env!("IMGPROXY_KEY"),
    salt: System.fetch_env!("IMGPROXY_SALT")

  config :since, Since.Bot,
    token: System.fetch_env!("TG_BOT_KEY"),
    room_id: System.fetch_env!("TG_ROOM_ID") |> String.to_integer()

  config :since, :s3,
    access_key_id: System.fetch_env!("AWS_ACCESS_KEY_ID"),
    secret_access_key: System.fetch_env!("AWS_SECRET_ACCESS_KEY"),
    region: "eu-north-1"

  config :since, Since.Media,
    user_bucket: System.fetch_env!("AWS_S3_BUCKET"),
    user_cdn: System.fetch_env!("USER_CDN"),
    static_bucket: System.fetch_env!("AWS_S3_BUCKET_STATIC"),
    static_cdn: System.fetch_env!("STATIC_CDN"),
    media_bucket: System.fetch_env!("AWS_S3_BUCKET_MEDIA"),
    media_cdn: System.fetch_env!("MEDIA_CDN")

  config :since, Since.Spotify,
    client_id: System.get_env("SPOTIFY_CLIENT_ID"),
    client_secret: System.get_env("SPOTIFY_CLIENT_SECRET")

  config :since, Since.Media.Static, disabled?: !!System.get_env("DISABLE_MEDIA")
  config :since, Since.Periodics, disabled?: !!System.get_env("DISABLE_PERIODICS")
end

if config_env() == :test do
  # Configure your database
  #
  # The MIX_TEST_PARTITION environment variable can be used
  # to provide built-in test partitioning in CI environment.
  # Run `mix help test` for more information.
  config :since, Since.Repo,
    url: "ecto://postgres:postgres@localhost:5432/t_test#{System.get_env("MIX_TEST_PARTITION")}",
    pool: Ecto.Adapters.SQL.Sandbox

  # We don't run a server during test. If one is required,
  # you can enable the server option below.
  config :since, SinceWeb.Endpoint,
    secret_key_base: "G3Ln+/DGlLRcc0cFikD44j8AS16t7ab5g0CjqhGBkOz2ol5GjHemYelcDWDEjkw5",
    url: [host: "localhost"],
    http: [port: 4002],
    server: false

  # Print only errors during test
  config :logger, level: :error

  config :since, Oban, queues: false, plugins: false

  config :since, :s3,
    access_key_id: "AKIAIOSFODNN7EXAMPLE",
    secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
    region: "eu-north-1"

  config :since, Since.Media,
    user_bucket: "pretend-this-is-real",
    static_bucket: "pretend-this-is-static",
    media_bucket: "pretend-this-is-media",
    user_cdn: "https://d1234.cloudfront.net",
    static_cdn: "https://d4321.cloudfront.net",
    media_cdn: "https://d6666.cloudfront.net"

  config :since, Since.Spotify,
    client_id: System.get_env("SPOTIFY_CLIENT_ID") || "SPOTIFY_CLIENT_ID",
    client_secret: System.get_env("SPOTIFY_CLIENT_SECRET") || "SPOTIFY_CLIENT_SECRET"

  config :since, AppStore,
    key: %{
      key: System.get_env("APP_STORE_KEY") || "APP_STORE_KEY",
      key_id: System.get_env("APP_STORE_KEY_ID") || "APP_STORE_KEY_ID",
      issuer_id: System.get_env("APP_STORE_ISSUER_ID") || "APP_STORE_ISSUER_ID",
      topic: System.get_env("APNS_TOPIC") || "APNS_TOPIC",
      env: :dev
    }

  config :imgproxy,
    prefix: "https://d1234.cloudfront.net",
    key: "fafafa",
    salt: "bababa"

  config :since, Since.Bot,
    token: "asdfasdfasdf",
    room_id: String.to_integer("-1234")

  config :since, Since.PushNotifications.APNS, default_topic: "app.topic"
  config :since, Since.Periodics, disabled?: true
  config :since, Finch, disabled?: false
  config :since, AppStore.Notificator, disabled?: true
end
