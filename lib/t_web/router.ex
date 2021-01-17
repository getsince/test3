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

  # TODO allow in prod under basic auth
  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through [:fetch_session, :protect_from_forgery]
      live_dashboard "/dashboard", metrics: TWeb.Telemetry
    end
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

  pipeline :with_current_user_from_bearer_token do
    plug :fetch_current_user_from_bearer_token
  end

  scope "/mobile/api/auth", TWeb do
    pipe_through [:api, :with_current_user_from_bearer_token, :require_not_authenticated_user]
    post "/request-sms", MobileAuthController, :request_sms
    post "/verify-phone-number", MobileAuthController, :verify_phone_number
  end
end
