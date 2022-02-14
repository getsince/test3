import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.

config :t, TWeb.Endpoint,
  render_errors: [view: TWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: T.PubSub,
  live_view: [signing_salt: "Urm6JRcI"]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :user_id, :remote_ip]

config :logger,
  utc_log: true,
  metadata: [:user_id, :remote_ip],
  format: "$time $metadata[$level] $message\n"

config :sentry,
  environment_name: config_env(),
  included_environments: [:prod]

config :t, T.PromEx, disabled: config_env() != :prod

config :t, Oban,
  repo: T.Repo,
  plugins: [
    Oban.Plugins.Pruner,
    Oban.Plugins.Stager
  ],
  queues: [default: 10, apns: 100]

config :ex_aws,
  json_codec: Jason,
  region: "eu-north-1"

if config_env() == :prod do
  config :t, current_admin_id: System.fetch_env!("ADMIN_ID")

  config :t, T.Twilio,
    account_sid: System.fetch_env!("TWILIO_ACCOUNT_SID"),
    key_sid: System.fetch_env!("TWILIO_KEY_SID"),
    auth_token: System.fetch_env!("TWILIO_AUTH_TOKEN")

  config :logger, backends: [:console, CloudWatch, Sentry.LoggerBackend]
  config :logger, :console, level: :info

  config :logger, CloudWatch,
    level: :warn,
    metadata: [:user_id, :remote_ip],
    log_stream_name: "backend",
    log_group_name: "prod"

  config :sentry,
    dsn: System.fetch_env!("SENTRY_DSN")

  config :t, T.PromEx,
    manual_metrics_start_delay: :no_delay,
    drop_metrics_groups: [],
    grafana: :disabled,
    metrics_server: :disabled

  config :t, T.Bot,
    token: System.fetch_env!("TG_BOT_KEY"),
    room_id: System.fetch_env!("TG_ROOM_ID") |> String.to_integer()

  config :t, APNS,
    keys: [
      %{
        key: System.fetch_env!("SANDBOX_APNS_KEY"),
        key_id: System.fetch_env!("SANDBOX_APNS_KEY_ID"),
        team_id: System.fetch_env!("APNS_TEAM_ID"),
        topic: System.fetch_env!("APNS_TOPIC"),
        env: :dev
      },
      %{
        key: System.fetch_env!("PROD_APNS_KEY"),
        key_id: System.fetch_env!("PROD_APNS_KEY_ID"),
        team_id: System.fetch_env!("APNS_TEAM_ID"),
        topic: System.fetch_env!("APNS_TOPIC"),
        env: :prod
      }
    ]

  config :t, T.PushNotifications.APNS, default_topic: System.fetch_env!("APNS_TOPIC")

  config :t, run_migrations_on_start?: true

  config :t, T.Repo,
    url: System.fetch_env!("DATABASE_URL"),
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "20")

  config :t, TWeb.Endpoint,
    # For production, don't forget to configure the url host
    # to something meaningful, Phoenix uses this information
    # when generating URLs.
    url: [scheme: "https", host: System.fetch_env!("HOST"), port: 443],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: String.to_integer(System.get_env("PORT") || "4000")
    ],
    secret_key_base: System.fetch_env!("SECRET_KEY_BASE"),
    server: true

  config :t, :dashboard,
    username: System.fetch_env!("DASHBOARD_USERNAME"),
    password: System.fetch_env!("DASHBOARD_PASSWORD")

  config :t, maxmind_license_key: System.fetch_env!("MAXMIND_LICENSE_KEY")

  config :imgproxy,
    prefix: System.fetch_env!("IMGPROXY_PREFIX"),
    key: System.fetch_env!("IMGPROXY_KEY"),
    salt: System.fetch_env!("IMGPROXY_SALT")

  config :t, T.Media,
    user_bucket: System.fetch_env!("AWS_S3_BUCKET"),
    static_bucket: System.fetch_env!("AWS_S3_BUCKET_STATIC"),
    static_cdn: System.fetch_env!("STATIC_CDN")

  config :t, T.Events,
    buffers: [:seen_buffer, :like_buffer, :contact_buffer],
    bucket: System.fetch_env!("AWS_S3_BUCKET_EVENTS")
end

if config_env() == :dev do
  config :logger, :console, level: :warn
  config :logger, backends: [:console]

  config :t, APNS,
    keys: [
      %{
        key: System.fetch_env!("SANDBOX_APNS_KEY"),
        key_id: System.fetch_env!("SANDBOX_APNS_KEY_ID"),
        team_id: System.fetch_env!("APNS_TEAM_ID"),
        topic: System.fetch_env!("APNS_TOPIC"),
        env: :dev
      }
    ]

  config :t, T.PushNotifications.APNS, default_topic: System.fetch_env!("APNS_TOPIC")

  config :t, T.Twilio,
    account_sid: System.fetch_env!("TWILIO_ACCOUNT_SID"),
    key_sid: System.fetch_env!("TWILIO_KEY_SID"),
    auth_token: System.fetch_env!("TWILIO_AUTH_TOKEN")

  # For development, we disable any cache and enable
  # debugging.
  #
  # The watchers configuration can be used to run external
  # watchers to your application. For example, we use it
  # with esbuild to bundle .js and .css sources.
  config :t, TWeb.Endpoint,
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
        ~r"lib/t_web/(live|views)/.*(ex)$",
        ~r"lib/t_web/templates/.*(eex)$"
      ]
    ],
    watchers: [
      yarn: ["watch:js", cd: Path.expand("../assets", __DIR__)],
      yarn: ["watch:css", cd: Path.expand("../assets", __DIR__)]
    ]

  # Configure your database
  config :t, T.Repo,
    url: System.get_env("DATABASE_URL") || "ecto://postgres:postgres@localhost:5432/t_dev",
    show_sensitive_data_on_connection_error: true,
    pool_size: 10

  config :t, :dashboard,
    username: System.fetch_env!("DASHBOARD_USERNAME"),
    password: System.fetch_env!("DASHBOARD_PASSWORD")

  config :imgproxy,
    prefix: System.fetch_env!("IMGPROXY_PREFIX"),
    key: System.fetch_env!("IMGPROXY_KEY"),
    salt: System.fetch_env!("IMGPROXY_SALT")

  config :t, T.Bot,
    token: System.fetch_env!("TG_BOT_KEY"),
    room_id: System.fetch_env!("TG_ROOM_ID") |> String.to_integer()

  config :t, T.Media,
    user_bucket: System.fetch_env!("AWS_S3_BUCKET"),
    static_bucket: System.fetch_env!("AWS_S3_BUCKET_STATIC"),
    static_cdn: System.fetch_env!("STATIC_CDN")

  config :t, T.Events, buffers: false, bucket: System.get_env("AWS_S3_BUCKET_EVENTS")
  config :t, T.Media.Static, disabled?: !!System.get_env("DISABLE_MEDIA")
  config :t, T.Periodics, disabled?: !!System.get_env("DISABLE_PERIODICS")
end

if config_env() == :test do
  config :t, current_admin_id: "36a0a181-db31-400a-8397-db7f560c152e"

  # Configure your database
  #
  # The MIX_TEST_PARTITION environment variable can be used
  # to provide built-in test partitioning in CI environment.
  # Run `mix help test` for more information.
  config :t, T.Repo,
    username: "postgres",
    password: "postgres",
    database: "t_test#{System.get_env("MIX_TEST_PARTITION")}",
    hostname: "localhost",
    pool: Ecto.Adapters.SQL.Sandbox

  # We don't run a server during test. If one is required,
  # you can enable the server option below.
  config :t, TWeb.Endpoint,
    secret_key_base: "G3Ln+/DGlLRcc0cFikD44j8AS16t7ab5g0CjqhGBkOz2ol5GjHemYelcDWDEjkw5",
    url: [host: "localhost"],
    http: [port: 4002],
    server: false

  # Print only errors during test
  config :logger, level: :error

  config :t, Oban, queues: false, plugins: false

  config :t, T.Media,
    user_bucket: "pretend-this-is-real",
    static_bucket: "pretend-this-is-static",
    static_cdn: "https://d4321.cloudfront.net"

  config :ex_aws,
    access_key_id: "AWS_ACCESS_KEY_ID",
    secret_access_key: "AWS_SECRET_ACCESS_KEY"

  config :imgproxy,
    prefix: "https://d1234.cloudfront.net",
    key: "fafafa",
    salt: "bababa"

  config :t, T.Bot,
    token: "asdfasdfasdf",
    room_id: String.to_integer("-1234")

  config :t, T.PushNotifications.APNS, default_topic: "app.topic"
  config :t, T.Periodics, disabled?: true
  config :t, Finch, disabled?: true
end

if config_env() == :bench do
  config :logger, level: :info

  config :t, T.Media.Static, disabled?: true
  config :t, Oban, queues: false, plugins: false
  config :t, T.Feeds.SeenPruner, disabled?: true
  config :t, T.Matches.MatchExpirer, disabled?: true
  config :t, T.PushNotifications.ScheduledPushes, disabled?: true
  config :t, T.Matches.TimeslotPruner, disabled?: true
  config :t, Finch, disabled?: true

  config :t, T.Repo,
    url: System.get_env("DATABASE_URL") || "ecto://postgres:postgres@localhost:5432/t_dev",
    pool_size: 10
end
