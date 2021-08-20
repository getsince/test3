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
    post "/request-sms", MobileAuthController, :request_sms
    post "/verify-phone", MobileAuthController, :verify_phone_number
    post "/verify-apple", MobileAuthController, :verify_apple_id
  end

  scope "/api", TWeb do
    pipe_through [:api, :fetch_current_user_from_bearer_token, :require_authenticated_user]
    get "/ip-location", LocationController, :get
    post "/upload-preflight", MediaController, :create_upload_form
    post "/ios/device-token", DeviceController, :create_ios_token
    post "/ios/push-token", DeviceController, :create_push_token
    delete "/mobile/account", MobileAccountController, :delete
    delete "/mobile/auth", MobileAuthController, :delete
    resources "/profile", ProfileController, singleton: true, only: [:update]
  end

  scope "/admin", TWeb do
    pipe_through [:browser, :dashboard_auth]

    live "/", AdminLive.Index, :index

    live "/support", SupportLive.Index, :index
    live "/support/:user_id", SupportLive.Index, :show

    live "/audio", AudioLive.PickUser, :pick_user, as: :audio
    live "/audio/:user_id", AudioLive.PickMatch, :pick_match, as: :audio
    live "/audio/:user_id/:mate_id", AudioLive.Index, :match, as: :audio

    live "/matches", MatchLive.Index, :index
    live "/matches/:user_id", MatchLive.Index, :show
    live "/matches/:user_id/call/:mate_id", MatchLive.Index, :call

    live "/trace/calls", TraceLive.Index, :index
    live "/trace/calls/:user_id", TraceLive.Show, :show

    live "/stickers", StickerLive.Index, :index
    live "/tokens", TokenLive.Index, :index
  end

  scope "/api/bot", TWeb do
    pipe_through [:api]

    post "/:token", BotController, :webhook
  end
end
