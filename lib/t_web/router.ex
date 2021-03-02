defmodule TWeb.Router do
  use TWeb, :router

  import TWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {TWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # TODO add app routes
  # TODO /onboarding
  # /login
  # /profile/<uuid>
  # /profile
  # /match
  # /feed
  # TODO add channel api explorer
  # TODO add admin interface with impersonation and bird view
  # TODO add reports endpoint

  # TODO https://hexdocs.pm/sentry/Sentry.Context.html#content
  scope "/api", TWeb do
    pipe_through :api

    # post "/share-email", ShareController, :email
    post "/share-phone", ShareController, :phone
    post "/visited", VisitController, :create
    get "/is-code-available/:code", ShareController, :check_if_available
    post "/save-code", ShareController, :save_code
  end

  if Mix.env() == :dev do
    forward "/sent-emails", Bamboo.SentEmailViewerPlug

    # scope "/api/dev", TWeb do
    #   pipe_through :api
    #   post "/phone-code", DevController, :get_phone_code
    # end
  end

  import Phoenix.LiveDashboard.Router

  scope "/" do
    pipe_through [
      :fetch_session,
      :protect_from_forgery,
      :put_secure_browser_headers,
      :dashboard_auth
    ]

    live_dashboard "/api/dashboard",
      metrics: TWeb.Telemetry,
      ecto_repos: [T.Repo]
  end

  ## Authentication routes

  # scope "/api/auth", TWeb do
  #   pipe_through [:api, :with_current_user, :require_not_authenticated_user]

  #   post "/request-sms", AuthController, :request_sms
  #   post "/verify-phone-number", AuthController, :verify_phone_number
  # end

  scope "/api/mobile/auth", TWeb do
    pipe_through [:api, :fetch_current_user_from_bearer_token, :require_not_authenticated_user]
    post "/request-sms", MobileAuthController, :request_sms
    post "/verify-phone", MobileAuthController, :verify_phone_number
  end

  scope "/api", TWeb do
    pipe_through [:api, :fetch_current_user_from_bearer_token, :require_authenticated_user]
    post "/upload-preflight", MediaController, :create_upload_form
    post "/ios/device-token", DeviceController, :create_ios_token
    get "/ios/yo-ack/:ack_id", YoController, :ack_ios_yo
    post "/ios/yo-ack", YoController, :ack_ios_yo
    delete "/mobile/account", MobileAccountController, :delete
    delete "/mobile/auth", MobileAuthController, :delete
    resources "/profile", ProfileController, singleton: true, only: [:update]
  end

  scope "/admin", TWeb do
    pipe_through [:browser, :dashboard_auth]

    live "/support", SupportLive.Index, :index
    live "/support/:user_id", SupportLive.Index, :show

    live "/audio", AudioLive.PickUser, :pick_user, as: :audio
    live "/audio/:user_id", AudioLive.PickMatch, :pick_match, as: :audio
    live "/audio/:user_id/:mate_id", AudioLive.Index, :match, as: :audio

    live "/matches", MatchLive.Index, :index
    live "/matches/:user_id", MatchLive.Index, :show
    live "/matches/:user_id/call/:mate_id", MatchLive.Index, :call
  end
end
