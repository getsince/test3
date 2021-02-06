import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :t, TWeb.Endpoint,
  render_errors: [view: TWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: T.PubSub,
  live_view: [signing_salt: "Urm6JRcI"]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :logger,
  backends: [:console, Sentry.LoggerBackend]

config :sentry,
  environment_name: config_env(),
  included_environments: [:prod]

config :logger, Sentry.LoggerBackend,
  level: :warn,
  capture_log_messages: true

config :t, Oban,
  repo: T.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10, emails: 20, sms: 20, personality: 20, apns: 100]

config :ex_aws,
  json_codec: Jason,
  region: "eu-central-1"

if config_env() == :prod do
  config :sentry,
    dsn: System.fetch_env!("SENTRY_DSN")

  config :pigeon, :apns,
    apns_default: %{
      key: System.fetch_env!("APNS_KEY"),
      key_identifier: System.fetch_env!("APNS_KEY_ID"),
      team_id: System.fetch_env!("APNS_TEAM_ID"),
      topic: System.fetch_env!("APNS_TOPIC"),
      # TODO
      mode: :dev
    }

  config :t, run_migrations_on_start?: true

  config :t, T.Mailer,
    adapter: Bamboo.SesAdapter,
    ex_aws: [region: "eu-central-1"]

  decode_cert = fn cert ->
    [{:Certificate, der, _}] = :public_key.pem_decode(cert)
    der
  end

  decode_key = fn cert ->
    [{:RSAPrivateKey, key, :not_encrypted}] = :public_key.pem_decode(cert)
    {:RSAPrivateKey, key}
  end

  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  ca_cert = System.get_env("DATABASE_CA_CERT")
  client_key = System.get_env("DATABASE_CLIENT_KEY")
  client_cert = System.get_env("DATABASE_CLIENT_CERT")

  ssl_opts =
    if ca_cert do
      [
        cacerts: [decode_cert.(ca_cert)],
        key: decode_key.(client_key),
        cert: decode_cert.(client_cert)
      ]
    end

  config :t, T.Repo,
    ssl_opts: ssl_opts,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "20")

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.fetch_env!("HOST")
  config :t, T.Mailer, our_address: "kindly@#{host}"

  config :t, TWeb.Endpoint,
    # For production, don't forget to configure the url host
    # to something meaningful, Phoenix uses this information
    # when generating URLs.
    url: [host: host, port: 80],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: String.to_integer(System.get_env("PORT") || "4000")
    ],
    secret_key_base: secret_key_base,
    server: true

  # Do not print debug messages in production
  config :logger, level: :info

  config :t, :dashboard,
    username: System.fetch_env!("DASHBOARD_USERNAME"),
    password: System.fetch_env!("DASHBOARD_PASSWORD")

  config :imgproxy,
    prefix: System.fetch_env!("IMGPROXY_PREFIX"),
    key: System.fetch_env!("IMGPROXY_KEY"),
    salt: System.fetch_env!("IMGPROXY_SALT")

  config :ex_aws,
    s3: [
      bucket: System.fetch_env!("AWS_S3_BUCKET")
    ]

  if demo_phones = System.get_env("DEMO_PHONES") do
    demo_phones
    |> String.split(",")
    |> Enum.each(fn phone_and_code ->
      [phone, code] = String.split(phone_and_code, ":")
      T.Accounts.add_demo_phone(phone, code)
    end)
  end
end

if config_env() == :dev do
  config :pigeon, :apns,
    apns_default: %{
      key: System.fetch_env!("APNS_KEY"),
      key_identifier: System.fetch_env!("APNS_KEY_ID"),
      team_id: System.fetch_env!("APNS_TEAM_ID"),
      topic: System.fetch_env!("APNS_TOPIC"),
      mode: :dev
    }

  config :t, :dashboard, username: "test", password: "test"

  config :t, T.Mailer,
    adapter: Bamboo.LocalAdapter,
    #   adapter: Bamboo.SesAdapter,
    #   ex_aws: [region: "eu-central-1"],
    our_address: "kindly@example.com"

  # For development, we disable any cache and enable
  # debugging.
  #
  # The watchers configuration can be used to run external
  # watchers to your application. For example, we use it
  # with webpack to recompile .js and .css sources.
  config :t, TWeb.Endpoint,
    http: [port: 4000],
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
      node: [
        "node_modules/webpack/bin/webpack.js",
        "--mode",
        "development",
        "--watch-stdin",
        cd: Path.expand("../assets", __DIR__)
      ]
    ]

  # Configure your database
  config :t, T.Repo,
    # username: "postgres",
    # password: "postgres",
    # database: "t_dev",
    # hostname: "localhost",
    url: System.fetch_env!("DATABASE_URL"),
    show_sensitive_data_on_connection_error: true,
    pool_size: 10

  config :t, :dashboard,
    username: System.fetch_env!("DASHBOARD_USERNAME"),
    password: System.fetch_env!("DASHBOARD_PASSWORD")

  config :imgproxy,
    prefix: System.fetch_env!("IMGPROXY_PREFIX"),
    key: System.fetch_env!("IMGPROXY_KEY"),
    salt: System.fetch_env!("IMGPROXY_SALT")

  # Do not include metadata nor timestamps in development logs
  config :logger, :tonsole, format: "[$level] $message\n"

  config :ex_aws,
    s3: [
      bucket: System.fetch_env!("AWS_S3_BUCKET")
    ]
end

if config_env() == :test do
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

  # Print only warnings and errors during test
  config :logger, level: :warn

  config :t, Oban, crontab: false, queues: false, plugins: false
  config :t, T.Mailer, adapter: Bamboo.TestAdapter, our_address: "kindly@example.com"

  config :ex_aws,
    access_key_id: "AWS_ACCESS_KEY_ID",
    secret_access_key: "AWS_SECRET_ACCESS_KEY",
    s3: [
      bucket: "pretend-this-is-real"
    ]

  config :imgproxy,
    prefix: "https://pretend-this-is-real.example.com",
    key: "fafafa",
    salt: "bababa"
end
