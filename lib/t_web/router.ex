defmodule TWeb.Router do
  use TWeb, :router

  import TWeb.UserAuth

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

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api/mobile/auth", TWeb do
    pipe_through [:api, :fetch_current_user_from_bearer_token, :require_not_authenticated_user]
    post "/request-sms", MobileAuthController, :request_sms
    post "/verify-phone", MobileAuthController, :verify_phone_number
  end
end
