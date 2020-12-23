defmodule TWeb.Router do
  use TWeb, :router

  import TWeb.UserAuth

  pipeline :api do
    plug :accepts, ["json"]
    # TODO put secure browser headers in sapper
  end

  pipeline :with_session do
    # TODO fetch session or bearer token
    plug :fetch_session
    plug :fetch_current_user
    # TODO protect from forgery
  end

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
  end

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

  scope "/api/auth", TWeb do
    pipe_through [:api, :with_session, :require_not_authenticated_user]

    post "/request-sms", AuthController, :request_sms
    post "/verify-phone-number", AuthController, :verify_phone_number
  end

  scope "/api", TWeb do
    pipe_through [:api, :with_session, :require_authenticated_user]

    get "/me", MeController, :me
    get "/profile", MeController, :profile
  end
end
