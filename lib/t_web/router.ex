defmodule TWeb.Router do
  use TWeb, :router

  import Phoenix.LiveDashboard.Router
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

  scope "/api/mobile/auth", TWeb do
    pipe_through [:api, :fetch_current_user_from_bearer_token, :require_not_authenticated_user]
    post "/verify-apple", MobileAuthController, :verify_apple_id
  end

  scope "/api", TWeb do
    pipe_through [:api, :fetch_current_user_from_bearer_token, :require_authenticated_user]
    get "/ip-location", LocationController, :get
    post "/upload-preflight", MediaController, :create_upload_form
    post "/ios/device-token", DeviceController, :create_ios_token
    # TODO remove
    post "/ios/push-token", DeviceController, :create_push_token
    delete "/mobile/account", MobileAccountController, :delete
    delete "/mobile/auth", MobileAuthController, :delete
  end

  scope "/admin", TWeb do
    pipe_through [:browser, :dashboard_auth]

    live_session :admin do
      live "/", AdminLive.Index, :index
      live "/profiles", ProfileLive.Index, :index
      live "/stickers", StickerLive.Index, :index
      live "/tokens", TokenLive.Index, :index
      live "/tokens/:user_id", TokenLive.Index, :show
    end
  end

  scope "/api/bot", TWeb do
    pipe_through [:api]

    post "/:token", BotController, :webhook
  end
end
