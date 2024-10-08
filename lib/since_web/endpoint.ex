defmodule SinceWeb.Endpoint do
  use Sentry.PlugCapture
  use Phoenix.Endpoint, otp_app: :since

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_since_key",
    signing_salt: "jYcKOG7A"
  ]

  # TODO session
  socket "/api/socket", SinceWeb.UserSocket,
    websocket: [
      connect_info: [:peer_data, :x_headers],
      error_handler: {SinceWeb.UserSocket, :handle_error, []}
    ],
    longpoll: false

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/admin",
    from: :t,
    gzip: true,
    brotli: true,
    only: ~w(assets fonts images favicon.ico robots.txt)

  plug SinceWeb.Plugs.HealthCheck

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :t
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug RemoteIp
  plug SinceWeb.Plugs.ConfigureLoggerMetadata

  plug Sentry.PlugContext
  plug SinceWeb.Router
end
